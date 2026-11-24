// Autoavaliação dos alunos do profleoaf.pt (Cloudflare Worker "profleoaf-autoavaliacao", no endereço workers.dev).
// Worker próprio: não altera os Workers "profleoaf-resultados" nem "profleoaf-ferramentas".
// Guarda tudo no KV ligado como "AUTO". A lista de alunos NÃO está no repositório:
// o professor carrega-a na página autoavaliacao-resultados.html e fica só no KV.
// POST /auto/turma     -> { turma, codigo } devolve os alunos da turma (público, com o código da turma)
// POST /auto/resposta  -> guarda a autoavaliação de um aluno (público, com o código da turma)
// GET  /auto/config    -> configuração completa, com códigos e alunos (palavra-passe AUTO_KEY)
// PUT  /auto/config    -> guarda a configuração (palavra-passe AUTO_KEY)
// GET  /auto/respostas?periodo=1P -> todas as respostas do período (palavra-passe AUTO_KEY)
// DELETE /auto/resposta?periodo=1P&turma=...&numero=N -> apaga uma resposta (palavra-passe AUTO_KEY)
// O segredo AUTO_KEY define-se no painel do Cloudflare.

const ORIGENS = ['https://profleoaf.pt', 'https://www.profleoaf.pt'];

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
    if (!env.AUTO) return json(req, { erro: 'Falta ligar o KV "AUTO" a este Worker no Cloudflare.' }, 500);
    if (url.pathname.startsWith('/auto/')) return autoavaliacao(req, env, url);
    return json(req, { erro: 'Não encontrado' }, 404);
  },
};

// ---------- Autoavaliação ----------
const AUTO_ITENS = 6;
const texto = (v, max) => String(v ?? '').replace(/\s+/g, ' ').trim().slice(0, max);
const inteiro = (v, min, max) => Number.isInteger(v) && v >= min && v <= max;

async function autoConfig(env) {
  return (await env.AUTO.get('auto:config', 'json')) || { periodo: '1P', aberto: false, turmas: {} };
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
    const chave = 'auto:r:' + cfg.periodo + ':' + texto(b.turma, 20) + ':' + aluno.n;
    // Um aluno não pode substituir a resposta de outro: só o professor (palavra-passe AUTO_KEY) pode alterar uma resposta já guardada.
    const professor = await autorizado(req, env, 'AUTO_KEY');
    if (!professor && req.headers.get('Authorization')) { await espera(800); return json(req, { erro: 'Palavra-passe errada' }, 401); }
    if (!professor && await env.AUTO.get(chave)) return json(req, { erro: 'Já existe uma autoavaliação para este nome. Se te enganaste, fala com o professor.' }, 409);
    const r = { turma: texto(b.turma, 20), numero: aluno.n, nome: aluno.nome, itens: b.itens, nivel: b.nivel,
      porque: texto(b.porque, 400), melhorar: texto(b.melhorar, 400), data: new Date().toISOString(), ...(professor ? { origem: 'papel' } : {}) };
    await env.AUTO.put(chave, JSON.stringify(r));
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
    await env.AUTO.put('auto:config', JSON.stringify(cfg));
    return json(req, { ok: true, turmas: Object.keys(turmas).length });
  }

  if (p === '/auto/respostas' && req.method === 'GET') {
    const periodo = texto(url.searchParams.get('periodo'), 10) || (await autoConfig(env)).periodo;
    const pref = 'auto:r:' + periodo + ':';
    const out = []; let cursor;
    do {
      const l = await env.AUTO.list({ prefix: pref, cursor });
      const vals = await Promise.all(l.keys.map(k => env.AUTO.get(k.name, 'json')));
      out.push(...vals.filter(Boolean));
      cursor = l.list_complete ? null : l.cursor;
    } while (cursor);
    return json(req, { periodo, respostas: out });
  }

  if (p === '/auto/resposta' && req.method === 'DELETE') {
    const k = 'auto:r:' + texto(url.searchParams.get('periodo'), 10) + ':' + texto(url.searchParams.get('turma'), 20) + ':' + parseInt(url.searchParams.get('numero'), 10);
    await env.AUTO.delete(k);
    return json(req, { ok: true });
  }

  return json(req, { erro: 'Não encontrado' }, 404);
}
