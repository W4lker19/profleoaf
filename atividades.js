// Lista das atividades do site "Aulas do Prof. Leo".
// Normalmente gere-se na página admin.html. Se editares à mão:
//   "estado": "visivel"  -> aparece já
//   "estado": "oculta"   -> não aparece
//   "estado": "agendada" -> aparece a partir de "disponivelEm" (data e hora em formato ISO)
//   "icone": "robo", "conversa", "codigo", "microbit", "seguranca", "blocos", "carro" ou "estrela"
//   "pagina": "pedro" -> a atividade aparece só em profleoaf.pt/pedro (e não na página principal)
//   "tipo": "formulario" + "url": "https://..." -> aparece na aba Formulários e abre o link (sem "ficheiro")
// Mantém o formato JSON (aspas duplas) entre as marcas ATIVIDADES-INICIO e ATIVIDADES-FIM.
// Para ver uma atividade que ainda não está disponível, abre o endereço dela com #preview no fim.

window.ATIVIDADES = /*ATIVIDADES-INICIO*/[
  {
    "ficheiro": "missao-seguranca.html",
    "disciplina": "TIC · 7.º ano",
    "tema": "Segurança",
    "icone": "seguranca",
    "titulo": "Segurança digital",
    "descricao": "Identifica os sinais de alerta em mensagens falsas e verifica a proteção do teu computador.",
    "estado": "agendada",
    "disponivelEm": "2026-11-09T08:00:00"
  },
  {
    "ficheiro": "conviver-na-internet.html",
    "disciplina": "CEA-STEAM · 5.º ano",
    "tema": "Cidadania digital",
    "icone": "conversa",
    "titulo": "Conviver na Internet",
    "descricao": "Uma semana no grupo da turma: decide o que fazer em cada situação e vê como as tuas escolhas mudam o ambiente do grupo.",
    "estado": "oculta",
    "disponivelEm": null
  },
  {
    "ficheiro": "robo-programador.html",
    "disciplina": "CEA-STEAM · 5.º ano",
    "tema": "Algoritmia",
    "icone": "robo",
    "titulo": "Robô Programador",
    "descricao": "Escreve a sequência de instruções e leva o robô até ao tesouro. Seis níveis, cada um mais difícil.",
    "estado": "oculta",
    "disponivelEm": null
  },
  {
    "ficheiro": "conviver-na-internet-quiz.html",
    "disciplina": "CEA-STEAM · 5.º ano",
    "tema": "Cidadania digital",
    "icone": "seguranca",
    "titulo": "Conviver na Internet (quiz)",
    "descricao": "Versão em quiz: 10 situações sobre netiqueta, ciberbullying e dados pessoais, com uma pergunta de cada vez.",
    "estado": "oculta",
    "disponivelEm": null
  },
  {
    "ficheiro": "pedro/torres-de-cores.html",
    "pagina": "pedro",
    "disciplina": "CEA-STEAM",
    "tema": "Cores e padrões",
    "icone": "blocos",
    "titulo": "Torres de cores",
    "descricao": "Copiar torres de blocos, descobrir padrões e fazer torres de memória.",
    "estado": "oculta",
    "disponivelEm": null
  },
  {
    "ficheiro": "pedro/carro-garagem.html",
    "pagina": "pedro",
    "disciplina": "CEA-STEAM",
    "tema": "Caminhos e setas",
    "icone": "carro",
    "titulo": "Leva o carro à garagem",
    "descricao": "Pinta o teu carro na oficina, programa o caminho até à garagem (com bomba de gasolina e cones) e descobre qual dos programas leva o carro ao destino.",
    "estado": "oculta",
    "disponivelEm": null
  },
  {
    "ficheiro": "pedro/carro-inteligente.html",
    "pagina": "pedro",
    "disciplina": "CEA-STEAM",
    "tema": "Sensor, decisão e ação",
    "icone": "carro",
    "titulo": "O carro inteligente",
    "descricao": "O carro vê um semáforo, uma passadeira, um cone ou fica sem gasolina: decide o que ele faz e escreve as regras do carro.",
    "estado": "agendada",
    "disponivelEm": "2026-11-11T13:20:00.000Z"
  }
]/*ATIVIDADES-FIM*/;

// Diz se uma atividade está disponível agora (não é preciso mexer aqui)
window.atividadeDisponivel = function (a, agora) {
  agora = agora || new Date();
  if (a.estado === 'visivel') return true;
  if (a.estado === 'agendada' && a.disponivelEm) return agora >= new Date(a.disponivelEm);
  if (a.estado === undefined && typeof a.visivel === 'boolean') return a.visivel;
  return false;
};

// Proteção das páginas que ainda não estão disponíveis (não é preciso mexer aqui)
(function () {
  var nome = decodeURIComponent(location.pathname.split('/').pop() || 'index.html').replace(/\.html$/i, '');
  var base = function (f) { return f.split('/').pop().replace(/\.html$/i, ''); };
  if (nome === 'index' || nome === 'admin' || nome === '') return;
  var a = window.ATIVIDADES.find(function (x) { return x.ficheiro && base(x.ficheiro) === nome; });
  if (a && !window.atividadeDisponivel(a) && location.hash !== '#preview') location.replace(a.pagina ? '/' + a.pagina + '/' : '/');
})();
