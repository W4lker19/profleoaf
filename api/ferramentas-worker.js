// Ferramentas do profleoaf.pt (Cloudflare Worker "profleoaf-ferramentas", em ferramentas.profleoaf.pt).
// Separado do Worker dos resultados das atividades (api/worker.js), que não é alterado.
//
// Guarda o instalador do LimparBrowsers no KV ligado como "FICHEIROS" — fora do repositório
// público, porque o instalador tem lá dentro o código secreto da sala.
// PUT /instalador  -> guarda o instalador (segredo TOOLS_UPLOAD_KEY; usado pelo Painel do Professor)
// GET /info        -> versão e data do instalador (palavra-passe TOOLS_KEY)
// GET /instalador  -> descarrega o instalador (palavra-passe TOOLS_KEY)
// PUT /atualizacao -> guarda o programa para as atualizações automáticas dos PCs (TOOLS_UPLOAD_KEY).
//                     O ntfy.sh gratuito não aceita anexos deste tamanho, por isso o painel põe aqui
//                     o ficheiro e manda pelo ntfy só o endereço.
// GET /atualizacao/<sha256> -> descarrega esse programa. Não precisa de palavra-passe: este ficheiro
//                     não tem a sala dentro e os PCs só o aceitam com a assinatura do portátil do professor.
//                     Só responde se o SHA-256 for o da última atualização guardada.
// Os segredos TOOLS_UPLOAD_KEY e TOOLS_KEY definem-se no painel do Cloudflare.

const ORIGENS = ['https://profleoaf.pt', 'https://www.profleoaf.pt'];
const MAX_INSTALADOR = 25 * 1024 * 1024; // limite de um valor no KV

function cors(req) {
  const o = req.headers.get('Origin') || '';
  return {
    'Access-Control-Allow-Origin': ORIGENS.includes(o) ? o : ORIGENS[0],
    'Access-Control-Allow-Methods': 'GET, PUT, OPTIONS',
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

    if (url.pathname === '/atualizacao' && req.method === 'PUT') {
      if (!(await autorizado(req, env, 'TOOLS_UPLOAD_KEY'))) { await espera(800); return json(req, { erro: 'Chave de envio errada' }, 401); }
      const dados = await req.arrayBuffer();
      const b = new Uint8Array(dados);
      if (dados.byteLength < 1024 || dados.byteLength > MAX_INSTALADOR || b[0] !== 0x4d || b[1] !== 0x5a) {
        return json(req, { erro: 'Ficheiro inválido (tem de ser o programa .exe, até 25 MB)' }, 400);
      }
      const sha = [...new Uint8Array(await crypto.subtle.digest('SHA-256', dados))].map(x => x.toString(16).padStart(2, '0')).join('');
      const versao = String(req.headers.get('X-Versao') || '').replace(/[^0-9A-Za-z.\-]/g, '').slice(0, 40);
      const info = { sha, versao, data: new Date().toISOString(), tamanho: dados.byteLength };
      await env.FICHEIROS.put('atualizacao', dados, { metadata: info });
      return json(req, { ok: true, ...info });
    }

    if (url.pathname.startsWith('/atualizacao/') && req.method === 'GET') {
      const pedido = url.pathname.slice('/atualizacao/'.length).toLowerCase();
      if (!/^[0-9a-f]{64}$/.test(pedido)) return json(req, { erro: 'Não encontrado' }, 404);
      const { value, metadata } = await env.FICHEIROS.getWithMetadata('atualizacao', 'arrayBuffer');
      if (!value || !metadata || metadata.sha !== pedido) return json(req, { erro: 'Esta atualização já foi substituída por outra.' }, 404);
      return new Response(value, { headers: {
        'Content-Type': 'application/octet-stream',
        'Cache-Control': 'public, max-age=86400, immutable',
      } });
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
