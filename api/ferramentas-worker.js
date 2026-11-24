// Ferramentas do profleoaf.pt (Cloudflare Worker "profleoaf-ferramentas", em ferramentas.profleoaf.pt).
// Separado do Worker dos resultados das atividades (api/worker.js), que não é alterado.
//
// Guarda o instalador do LimparBrowsers no KV ligado como "FICHEIROS" — fora do repositório
// público, porque o instalador tem lá dentro o código secreto da sala.
// PUT /instalador  -> guarda o instalador (segredo TOOLS_UPLOAD_KEY; usado pelo Painel do Professor)
// GET /info        -> versão e data do instalador (palavra-passe TOOLS_KEY)
// GET /instalador  -> descarrega o instalador (palavra-passe TOOLS_KEY)
// Os segredos TOOLS_UPLOAD_KEY e TOOLS_KEY definem-se no painel do Cloudflare.
//
// Autoavaliação dos alunos (mesmo KV, chaves "auto:..."). A lista de alunos NÃO está no repositório:
// o professor carrega-a na página autoavaliacao-resultados.html e fica só no KV.
// POST /auto/turma     -> { turma, codigo } devolve os alunos da turma (público, com o código da turma)
// POST /auto/resposta  -> guarda a autoavaliação de um aluno (público, com o código da turma)
// GET  /auto/config    -> configuração completa, com códigos e alunos (palavra-passe AUTO_KEY)
// PUT  /auto/config    -> guarda a configuração (palavra-passe AUTO_KEY)
// GET  /auto/respostas?periodo=1P -> todas as respostas do período (palavra-passe AUTO_KEY)
// DELETE /auto/resposta?periodo=1P&turma=...&numero=N -> apaga uma resposta (palavra-passe AUTO_KEY)
// O segredo AUTO_KEY define-se no painel do Cloudflare.

const ORIGENS = ['https://profleoaf.pt', 'https://www.profleoaf.pt'];
const MAX_INSTALADOR = 25 * 1024 * 1024; // limite de um valor no KV

function cors(req) {
  const o = req.headers.get('Origin') || '';
  return {
    'Access-Control-Allow-Origin': ORIGENS.includes(o) ? o : ORIGENS[0],
    'Access-Control-Allow-Methods': 'GET, PUT, POST, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Versao',
    'Vary': 'Origin',
  };
}
const json = (req, data, status = 200) => new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json; charset=utf-8', ...cors(req) } });
const espera = ms => new Promise(r => setTimeout(r, ms)); // atrasa tentativas de adivinhar a palavra-passe

async function autorizado(req, env, segredo) {
  const h = req.headers.get('Authorization') || '';
  const dado = h.startsWith('Bearer ') ? h.slice(7) : '';
  if (!env[segredo] || !dado) return false;
  const enc = new TextEncoder();
  const [a, b] = await Promise.all([crypto.subtle.digest('SHA-256', enc.encode(dado)), crypto.subtle.digest('SHA-256', enc.encode(env[segredo]))]);
  const x = new Uint8Array(a), y = new Uint8Array(b);
  let d = 0; for (let i = 0; i < x.length; i++) d |= x[i] ^ y[i];
  return d === 0;
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors(req) });
    if (!env.FICHEIROS) return json(req, { erro: 'Falta ligar o KV "FICHEIROS" a este Worker no Cloudflare.' }, 500);

    if (url.pathname.startsWith('/auto/')) return autoavaliacao(req, env, url);

    if (url.pathname === '/instalador' && req.method === 'PUT') {
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

    if ((url.pathname === '/info' || url.pathname === '/instalador') && req.method === 'GET') {
      if (!(await autorizado(req, env, 'TOOLS_KEY'))) { await espera(800); return json(req, { erro: 'Palavra-passe errada' }, 401); }
      const { value, metadata } = await env.FICHEIROS.getWithMetadata('instalador', 'arrayBuffer');
      if (!value) return json(req, { erro: 'Ainda não foi publicado nenhum instalador.' }, 404);
      if (url.pathname === '/info') return json(req, metadata || {});
      return new Response(value, { headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Disposition': 'attachment; filename="Instalar LimparBrowsers.exe"',
        'Cache-Control': 'no-store',
        ...cors(req),
      } });
    }

    return json(req, { erro: 'Não encontrado' }, 404);
  },
};

// ---------- Autoavaliação ----------
const AUTO_ITENS = 6;
const texto = (v, max) => String(v ?? '').replace(/\s+/g, ' ').trim().slice(0, max);
const inteiro = (v, min, max) => Number.isInteger(v) && v >= min && v <= max;

async function autoConfig(env) {
  return (await env.FICHEIROS.get('auto:config', 'json')) || { periodo: '1P', aberto: false, turmas: {} };
}
function turmaValida(cfg, b) {
  const t = cfg.turmas[texto(b.turma, 20)];
  if (!t) return null;
  if (texto(b.codigo, 20).toUpperCase() !== String(t.codigo).toUpperCase()) return null;
  return t;
}

async function autoavaliacao(req, env, url) {
  const p = url.pathname;

  if (p === '/auto/turma' && req.method === 'POST') {
    let b; try { b = await req.json(); } catch (e) { return json(req, { erro: 'Pedido inválido' }, 400); }
    const cfg = await autoConfig(env);
    if (!cfg.aberto) return json(req, { erro: 'A autoavaliação está fechada.' }, 403);
    const t = turmaValida(cfg, b);
    if (!t) { await espera(600); return json(req, { erro: 'Turma ou código errado.' }, 401); }
    return json(req, { periodo: cfg.periodo, titulo: cfg.titulo || '', alunos: t.alunos.filter(a => a.ativo !== false).map(a => ({ n: a.n, nome: a.nome })) });
  }

  if (p === '/auto/resposta' && req.method === 'POST') {
    let b; try { b = await req.json(); } catch (e) { return json(req, { erro: 'Pedido inválido' }, 400); }
    const cfg = await autoConfig(env);
    if (!cfg.aberto) return json(req, { erro: 'A autoavaliação está fechada.' }, 403);
    const t = turmaValida(cfg, b);
    if (!t) { await espera(600); return json(req, { erro: 'Turma ou código errado.' }, 401); }
    const aluno = t.alunos.find(a => a.n === b.numero && a.ativo !== false);
    if (!aluno) return json(req, { erro: 'Aluno não encontrado.' }, 400);
    if (!Array.isArray(b.itens) || b.itens.length !== AUTO_ITENS || !b.itens.every(v => inteiro(v, 1, 5)) || !inteiro(b.nivel, 1, 5)) {
      return json(req, { erro: 'Responde a todas as linhas (1 a 5) e escolhe o nível.' }, 400);
    }
    const r = { turma: texto(b.turma, 20), numero: aluno.n, nome: aluno.nome, itens: b.itens, nivel: b.nivel,
      porque: texto(b.porque, 400), melhorar: texto(b.melhorar, 400), data: new Date().toISOString() };
    await env.FICHEIROS.put('auto:r:' + cfg.periodo + ':' + r.turma + ':' + r.numero, JSON.stringify(r));
    return json(req, { ok: true });
  }

  const pw = await autorizado(req, env, 'AUTO_KEY');
  if (!pw) { await espera(800); return json(req, { erro: 'Palavra-passe errada' }, 401); }

  if (p === '/auto/config' && req.method === 'GET') return json(req, await autoConfig(env));

  if (p === '/auto/config' && req.method === 'PUT') {
    let b; try { b = await req.json(); } catch (e) { return json(req, { erro: 'JSON inválido' }, 400); }
    const turmas = {};
    for (const [nome, t] of Object.entries(b.turmas || {})) {
      const alunos = (t.alunos || []).filter(a => inteiro(a.n, 1, 40) && texto(a.nome, 80)).map(a => ({ n: a.n, nome: texto(a.nome, 80), ativo: a.ativo !== false }));
      if (texto(nome, 20) && texto(t.codigo, 20)) turmas[texto(nome, 20)] = { codigo: texto(t.codigo, 20).toUpperCase(), alunos };
    }
    const cfg = { periodo: texto(b.periodo, 10) || '1P', titulo: texto(b.titulo, 80), aberto: b.aberto === true, turmas };
    await env.FICHEIROS.put('auto:config', JSON.stringify(cfg));
    return json(req, { ok: true, turmas: Object.keys(turmas).length });
  }

  if (p === '/auto/respostas' && req.method === 'GET') {
    const periodo = texto(url.searchParams.get('periodo'), 10) || (await autoConfig(env)).periodo;
    const pref = 'auto:r:' + periodo + ':';
    const out = []; let cursor;
    do {
      const l = await env.FICHEIROS.list({ prefix: pref, cursor });
      const vals = await Promise.all(l.keys.map(k => env.FICHEIROS.get(k.name, 'json')));
      out.push(...vals.filter(Boolean));
      cursor = l.list_complete ? null : l.cursor;
    } while (cursor);
    return json(req, { periodo, respostas: out });
  }

  if (p === '/auto/resposta' && req.method === 'DELETE') {
    const k = 'auto:r:' + texto(url.searchParams.get('periodo'), 10) + ':' + texto(url.searchParams.get('turma'), 20) + ':' + parseInt(url.searchParams.get('numero'), 10);
    await env.FICHEIROS.delete(k);
    return json(req, { ok: true });
  }

  return json(req, { erro: 'Não encontrado' }, 404);
}
