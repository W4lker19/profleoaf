// Serviço de resultados do profleoaf.pt (Cloudflare Worker + base de dados D1 ligada como "DB").
// POST /resultado        -> guarda o resultado de um aluno (público, usado pelas atividades)
// GET  /resultados?atividade=missao-seguranca  -> lista os resultados (precisa da palavra-passe)
// DELETE /resultado?id=N -> apaga um registo (precisa da palavra-passe)
// A palavra-passe é o segredo RESULTS_KEY, definido no painel do Cloudflare.
//
// Ferramentas (LimparBrowsers) — o instalador fica guardado no KV ligado como "FICHEIROS",
// fora do repositório público, porque tem lá dentro o código secreto da sala:
// PUT /tools/instalador  -> guarda o instalador (segredo TOOLS_UPLOAD_KEY; usado pelo Painel do Professor)
// GET /tools/info        -> versão e data do instalador (palavra-passe TOOLS_KEY)
// GET /tools/instalador  -> descarrega o instalador (palavra-passe TOOLS_KEY)

const ORIGENS = ['https://profleoaf.pt', 'https://www.profleoaf.pt'];
const ATIVIDADES = ['missao-seguranca'];
const TURMAS = ['7.º C', '7.º D', '7.º E', '7.º G', '7.º H', '5.º B', '5.º D', '5.º E', '5.º F', '5.º G'];

const SQL_TABELA = 'CREATE TABLE IF NOT EXISTS resultados (id INTEGER PRIMARY KEY AUTOINCREMENT, atividade TEXT NOT NULL, turma TEXT NOT NULL, numero INTEGER NOT NULL, nome TEXT NOT NULL, nota INTEGER NOT NULL, p1 INTEGER, p2 INTEGER, detalhes TEXT, criado TEXT NOT NULL)';

function cors(req) {
  const o = req.headers.get('Origin') || '';
  return {
    'Access-Control-Allow-Origin': ORIGENS.includes(o) ? o : ORIGENS[0],
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Vary': 'Origin',
  };
}
const json = (req, data, status = 200) => new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json; charset=utf-8', ...cors(req) } });

async function autorizado(req, env, segredo = 'RESULTS_KEY') {
  const h = req.headers.get('Authorization') || '';
  const dado = h.startsWith('Bearer ') ? h.slice(7) : '';
  if (!env[segredo] || !dado) return false;
  const enc = new TextEncoder();
  const [a, b] = await Promise.all([crypto.subtle.digest('SHA-256', enc.encode(dado)), crypto.subtle.digest('SHA-256', enc.encode(env[segredo]))]);
  const x = new Uint8Array(a), y = new Uint8Array(b);
  let d = 0; for (let i = 0; i < x.length; i++) d |= x[i] ^ y[i];
  return d === 0;
}
const inteiro = (v, min, max) => Number.isInteger(v) && v >= min && v <= max;
const MAX_INSTALADOR = 25 * 1024 * 1024; // limite de um valor no KV
const espera = ms => new Promise(r => setTimeout(r, ms)); // atrasa tentativas de adivinhar a palavra-passe

async function ferramentas(req, env, url) {
  if (!env.FICHEIROS) return json(req, { erro: 'Falta ligar o KV "FICHEIROS" a este Worker no Cloudflare.' }, 500);

  if (url.pathname === '/tools/instalador' && req.method === 'PUT') {
    if (!(await autorizado(req, env, 'TOOLS_UPLOAD_KEY'))) { await espera(800); return json(req, { erro: 'Chave de envio errada' }, 401); }
    const dados = await req.arrayBuffer();
    const b = new Uint8Array(dados);
    if (dados.byteLength < 1024 || dados.byteLength > MAX_INSTALADOR || b[0] !== 0x4d || b[1] !== 0x5a) {
      return json(req, { erro: 'Ficheiro inválido (tem de ser o instalador .exe, até 25 MB)' }, 400);
    }
    const versao = String(req.headers.get('X-Versao') || '').replace(/[^0-9A-Za-z.\-]/g, '').slice(0, 40);
    const info = { versao, data: new Date().toISOString(), tamanho: dados.byteLength };
    await env.FICHEIROS.put('instalador', dados, { metadata: info });
    return json(req, { ok: true, ...info });
  }

  if ((url.pathname === '/tools/info' || url.pathname === '/tools/instalador') && req.method === 'GET') {
    if (!(await autorizado(req, env, 'TOOLS_KEY'))) { await espera(800); return json(req, { erro: 'Palavra-passe errada' }, 401); }
    const { value, metadata } = await env.FICHEIROS.getWithMetadata('instalador', 'arrayBuffer');
    if (!value) return json(req, { erro: 'Ainda não foi publicado nenhum instalador.' }, 404);
    if (url.pathname === '/tools/info') return json(req, metadata || {});
    return new Response(value, { headers: {
      'Content-Type': 'application/octet-stream',
      'Content-Disposition': 'attachment; filename="Instalar LimparBrowsers.exe"',
      'Cache-Control': 'no-store',
      ...cors(req),
    } });
  }
  return json(req, { erro: 'Não encontrado' }, 404);
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors(req) });
    if (url.pathname.startsWith('/tools/')) return ferramentas(req, env, url);
    await env.DB.exec(SQL_TABELA);

    if (url.pathname === '/resultado' && req.method === 'POST') {
      let b; try { b = await req.json(); } catch (e) { return json(req, { erro: 'JSON inválido' }, 400); }
      const nome = String(b.nome || '').trim().slice(0, 60);
      const det = JSON.stringify(b.detalhes || {}).slice(0, 4000);
      if (!ATIVIDADES.includes(b.atividade) || !TURMAS.includes(b.turma) || !inteiro(b.numero, 1, 40) || nome.length < 2
        || !inteiro(b.nota, 0, 100) || !inteiro(b.p1 ?? 0, 0, 100) || !inteiro(b.p2 ?? 0, 0, 100)) {
        return json(req, { erro: 'Dados inválidos' }, 400);
      }
      const r = await env.DB.prepare('INSERT INTO resultados (atividade, turma, numero, nome, nota, p1, p2, detalhes, criado) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)')
        .bind(b.atividade, b.turma, b.numero, nome, b.nota, b.p1 ?? null, b.p2 ?? null, det, new Date().toISOString()).run();
      return json(req, { ok: true, id: r.meta.last_row_id });
    }

    if (url.pathname === '/resultados' && req.method === 'GET') {
      if (!(await autorizado(req, env))) return json(req, { erro: 'Palavra-passe errada' }, 401);
      const at = url.searchParams.get('atividade') || 'missao-seguranca';
      const { results } = await env.DB.prepare('SELECT id, turma, numero, nome, nota, p1, p2, detalhes, criado FROM resultados WHERE atividade = ? ORDER BY turma, numero, criado').bind(at).all();
      return json(req, { atividade: at, resultados: results });
    }

    if (url.pathname === '/resultado' && req.method === 'DELETE') {
      if (!(await autorizado(req, env))) return json(req, { erro: 'Palavra-passe errada' }, 401);
      const id = parseInt(url.searchParams.get('id'), 10);
      if (!id) return json(req, { erro: 'Falta o id' }, 400);
      await env.DB.prepare('DELETE FROM resultados WHERE id = ?').bind(id).run();
      return json(req, { ok: true });
    }

    return json(req, { erro: 'Não encontrado' }, 404);
  },
};
