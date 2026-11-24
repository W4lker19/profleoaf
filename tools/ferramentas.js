// Ferramentas da página profleoaf.pt/tools.
// Normalmente gere-se na página admin.html (secção "Ferramentas"). Se editares à mão:
//   "estado": "visivel" -> o cartão aparece em /tools
//   "estado": "oculta"  -> o cartão fica escondido
// O "id" liga cada entrada aos cartões com data-ferramenta="..." em tools/index.html.
// Mantém o formato JSON (aspas duplas) entre as marcas FERRAMENTAS-INICIO e FERRAMENTAS-FIM.
// Nota: ocultar só esconde o cartão. O LimparBrowsers continua protegido pela palavra-passe,
// mas o ficheiro otimizar-portatil.cmd continua a poder ser descarregado por quem souber o endereço.

window.FERRAMENTAS = /*FERRAMENTAS-INICIO*/[
  {
    "id": "limparbrowsers",
    "titulo": "LimparBrowsers",
    "descricao": "Instalador para os PCs da sala (termina as sessões dos alunos nos browsers).",
    "estado": "oculta"
  },
  {
    "id": "otimizar",
    "titulo": "Otimizar portátil",
    "descricao": "Limpeza e otimização do Windows e instalação das aplicações das aulas.",
    "estado": "visivel"
  }
]/*FERRAMENTAS-FIM*/;
