// Lista das atividades do site "Aulas do Prof. Leo".
// Normalmente gere-se na página admin.html. Se editares à mão:
//   "estado": "visivel"  -> aparece já
//   "estado": "oculta"   -> não aparece
//   "estado": "agendada" -> aparece a partir de "disponivelEm" (data e hora em formato ISO)
//   "icone": "robo", "conversa", "codigo", "microbit", "seguranca" ou "estrela"
// Mantém o formato JSON (aspas duplas) entre as marcas ATIVIDADES-INICIO e ATIVIDADES-FIM.
// Para ver uma atividade que ainda não está disponível, abre o endereço dela com #preview no fim.

window.ATIVIDADES = /*ATIVIDADES-INICIO*/[
  {
    "ficheiro": "conviver-na-internet.html",
    "disciplina": "CEA-STEAM · 5.º ano",
    "tema": "Cidadania digital",
    "icone": "conversa",
    "titulo": "Conviver na Internet",
    "descricao": "Uma semana no grupo da turma: decide o que fazer em cada situação e vê como as tuas escolhas mudam o ambiente do grupo.",
    "estado": "visivel",
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
  if (nome === 'index' || nome === 'admin' || nome === '') return;
  var a = window.ATIVIDADES.find(function (x) { return x.ficheiro.replace(/\.html$/i, '') === nome; });
  if (a && !window.atividadeDisponivel(a) && location.hash !== '#preview') location.replace('index.html');
})();
