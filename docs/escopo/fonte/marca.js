// Tokens da identidade visual da Aprimora (derivados da logo oficial e da Carta de Serviços).
const cores = {
  azul: "#24476F",        // fundo da logo oficial
  azulProfundo: "#1A3554",
  laranja: "#E8833A",
  azulClaro: "#97B9C6",
  fundoSuave: "#F2F5F9",
  fundoLaranja: "#FDF1E7",
  cinza: "#5B6573",
};
const fontes = { titulo: "Montserrat", texto: "Open Sans" };
const semCerquilha = (c) => c.replace("#", "");
module.exports = {
  cores, fontes,
  docx: {
    NAVY: semCerquilha(cores.azul), NAVY_DARK: semCerquilha(cores.azulProfundo), ORANGE: semCerquilha(cores.laranja),
    LIGHT_BLUE: semCerquilha(cores.azulClaro), BG_SOFT: semCerquilha(cores.fundoSuave), BG_ORANGE: semCerquilha(cores.fundoLaranja),
    GRAY: semCerquilha(cores.cinza), HFONT: fontes.titulo, BFONT: fontes.texto,
  },
};
