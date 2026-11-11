/*
 * Demostraciones e instrucciones para los ejercicios del catálogo.
 *
 * Las imágenes pertenecen a Free Exercise DB (Unlicense / dominio público):
 * https://github.com/yuhonas/free-exercise-db
 *
 * El objeto se indexa por el nombre exacto del ejercicio en MySQL para que
 * siga funcionando aunque cambien los IDs entre una instalación limpia y una
 * base de datos migrada.
 */
const DEMO_EJERCICIOS_BASE =
  "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/";

const DEMO_EJERCICIOS = {
  "Press de Banca Plano": {
    demo: "Barbell_Bench_Press_-_Medium_Grip",
    pasos: [
      "Acuéstate en el banco con los pies firmes en el suelo y las escápulas retraídas.",
      "Sujeta la barra un poco más ancha que los hombros y bájala controlada hasta la línea del pecho.",
      "Empuja la barra hacia arriba sin perder la posición de los hombros ni rebotar.",
    ],
    consejos: [
      "Mantén las muñecas alineadas con los antebrazos y los codos a unos 45° del torso.",
      "Respira al bajar y exhala durante el empuje; usa un compañero si levantas cargas máximas.",
    ],
  },
  "Dominadas en Barra": {
    demo: "Pullups",
    pasos: [
      "Cuélgate de la barra con agarre prono y el cuerpo estable.",
      "Inicia la tracción llevando los codos hacia las costillas hasta superar la barbilla.",
      "Baja controlado hasta extender los brazos sin balancearte.",
    ],
    consejos: [
      "Evita encoger los hombros; mantén el pecho alto y el core activo.",
      "Si no llegas a las repeticiones, usa banda elástica o asistencia.",
    ],
  },
  "Sentadilla Libre con Barra": {
    demo: "Barbell_Squat",
    pasos: [
      "Coloca la barra sobre los trapecios y separa los pies a la anchura de los hombros.",
      "Desciende flexionando cadera y rodillas con la espalda neutra.",
      "Empuja el suelo con los pies para subir manteniendo el torso firme.",
    ],
    consejos: [
      "Las rodillas deben seguir la dirección de los pies; no las dejes colapsar hacia dentro.",
      "Controla el descenso y evita levantar los talones.",
    ],
  },
  "Hip Thrust con barra": {
    demo: "Barbell_Hip_Thrust",
    pasos: [
      "Apoya la espalda alta en un banco y coloca la barra sobre la cadera con protección.",
      "Empuja con los talones para extender la cadera hasta alinear rodillas, cadera y hombros.",
      "Baja controlado sin perder la tensión del glúteo.",
    ],
    consejos: [
      "Mantén el mentón recogido y la barbilla cerca del pecho.",
      "Evita arquear en exceso la zona lumbar; el movimiento viene del glúteo.",
    ],
  },
  "Hip Thrust en máquina": {
    demo: "Barbell_Hip_Thrust",
    pasos: [
      "Ajusta la máquina y apoya la espalda alta en el respaldo.",
      "Coloca la almohadilla sobre la cadera y empuja con los talones.",
      "Extiende la cadera y regresa controlado sin soltar la tensión.",
    ],
    consejos: [
      "Verifica que la almohadilla quede sobre el hueso de la cadera, no sobre el abdomen.",
      "No bloquees la respiración en la parte alta.",
    ],
  },
  "Peso muerto rumano": {
    demo: "Romanian_Deadlift",
    pasos: [
      "De pie con la barra frente a los muslos y las rodillas ligeramente flexionadas.",
      "Lleva la cadera hacia atrás bajando la barra pegada a las piernas.",
      "Detente cuando sientas estiramiento en femorales y sube apretando glúteos.",
    ],
    consejos: [
      "Mantén la espalda neutra; no redondees la zona lumbar.",
      "La barra debe rozar el muslo y la espinilla durante todo el recorrido.",
    ],
  },
  "Peso muerto convencional": {
    demo: "Barbell_Deadlift",
    pasos: [
      "Pies a la anchura de la cadera, barra sobre el medio del pie.",
      "Agarra la barra, activa el core y empuja el suelo con las piernas.",
      "Extiende cadera y rodillas a la vez, manteniendo la barra cerca del cuerpo.",
    ],
    consejos: [
      "No tires con la espalda; inicia el movimiento con las piernas.",
      "Baja la barra controlada y reinicia cada repetición si la técnica se pierde.",
    ],
  },
  "Patada de glúteo en polea": {
    demo: "Glute_Kickback",
    pasos: [
      "Coloca el tobillo en la polea y apóyate en el soporte.",
      "Lleva la pierna hacia atrás manteniendo la cadera estable.",
      "Aprieta el glúteo arriba y regresa sin balancear el torso.",
    ],
    consejos: [
      "Evita arquear la lumbar para ganar recorrido.",
      "Usa un rango corto y controlado; prioriza la contracción.",
    ],
  },
  "Abductores en máquina o polea": {
    demo: "Thigh_Abductor",
    pasos: [
      "Siéntate en la máquina con la espalda apoyada y los muslos en las almohadillas.",
      "Separa las piernas contra la resistencia de forma controlada.",
      "Regresa lentamente sin dejar que el peso golpee.",
    ],
    consejos: [
      "Mantén el torso quieto y el core activo.",
      "No uses impulso; el movimiento debe ser lento y constante.",
    ],
  },
  "Curl femoral (tumbado o sentado)": {
    demo: "Lying_Leg_Curls",
    pasos: [
      "Ajusta la máquina para que la rodilla quede alineada con el eje.",
      "Flexiona las piernas llevando los talones hacia los glúteos.",
      "Baja controlado hasta casi extender las rodillas.",
    ],
    consejos: [
      "Evita despegar la cadera del asiento.",
      "Mantén los pies relajados y no balances el peso.",
    ],
  },
  Hiperextensiones: {
    demo: "Hyperextensions_Back_Extensions",
    pasos: [
      "Coloca la cadera sobre el soporte y fija los tobillos.",
      "Baja el torso con la espalda neutra hasta sentir estiramiento.",
      "Sube extendiendo la cadera sin hiperextender la lumbar.",
    ],
    consejos: [
      "No busques un rango excesivo; detente cuando el cuerpo esté alineado.",
      "Aprieta glúteos al final y evita usar impulso.",
    ],
  },
  "Sentadilla libre profunda": {
    demo: "Barbell_Full_Squat",
    pasos: [
      "Coloca la barra en los trapecios y activa el core.",
      "Desciende hasta que la cadera quede por debajo de las rodillas, si la movilidad lo permite.",
      "Sube empujando el suelo y manteniendo el pecho alto.",
    ],
    consejos: [
      "No sacrifiques la técnica por profundidad; trabaja la movilidad de tobillo y cadera.",
      "Mantén los talones apoyados y las rodillas alineadas.",
    ],
  },
  "Sentadilla en máquina Smith": {
    demo: "Smith_Machine_Squat",
    pasos: [
      "Coloca la barra en la posición alta y sitúate con los pies un poco adelantados.",
      "Desbloquea la barra y desciende controlado.",
      "Empuja con los talones y vuelve a bloquear al final.",
    ],
    consejos: [
      "Ajusta la barra para que no choque con el cuerpo.",
      "No bloquees las rodillas de golpe; mantén tensión.",
    ],
  },
  "Sentadilla Goblet": {
    demo: "Goblet_Squat",
    pasos: [
      "Sostén una mancuerna o kettlebell contra el pecho.",
      "Desciende con los codos dentro de las rodillas y el torso erguido.",
      "Sube empujando el suelo y apretando glúteos.",
    ],
    consejos: [
      "Mantén el peso pegado al pecho para no perder el equilibrio.",
      "Usa un rango que te permita mantener la espalda neutra.",
    ],
  },
  "Sentadilla búlgara": {
    demo: "Split_Squat_with_Dumbbells",
    pasos: [
      "Apoya el pie trasero en un banco y da un paso largo con el pie delantero.",
      "Desciende verticalmente flexionando la pierna delantera.",
      "Empuja el suelo para volver a la posición inicial.",
    ],
    consejos: [
      "Mantén el peso sobre el talón delantero.",
      "Ajusta la distancia del pie para sentir el trabajo en el glúteo y cuádriceps.",
    ],
  },
  "Prensa de piernas": {
    demo: "Leg_Press",
    pasos: [
      "Siéntate con la espalda y la cadera apoyadas, pies en la plataforma.",
      "Desbloquea y baja la plataforma controlando la flexión de rodillas.",
      "Empuja sin bloquear las rodillas al final.",
    ],
    consejos: [
      "No despega la cadera del asiento.",
      "No bajes tanto que la lumbar se redondee.",
    ],
  },
  Zancadas: {
    demo: "Dumbbell_Lunges",
    pasos: [
      "Con mancuernas a los lados, da un paso al frente y baja la rodilla trasera.",
      "Mantén el torso vertical y la rodilla delantera sobre el pie.",
      "Empuja con el pie delantero para volver.",
    ],
    consejos: [
      "Da un paso suficientemente largo para no cargar la rodilla.",
      "Controla el equilibrio y no cruces los pies.",
    ],
  },
  "Extensión de cuádriceps": {
    demo: "Leg_Extensions",
    pasos: [
      "Ajusta el respaldo y coloca las espinillas detrás de la almohadilla.",
      "Extiende las piernas hasta casi bloquear las rodillas.",
      "Baja controlado sin dejar caer el peso.",
    ],
    consejos: [
      "Aprieta el cuádriceps arriba sin arquear la lumbar.",
      "Mantén la cadera pegada al asiento.",
    ],
  },
  "Elevación de talones de pie": {
    demo: "Standing_Calf_Raises",
    pasos: [
      "Coloca los hombros bajo las almohadillas y los metatarsos en la plataforma.",
      "Sube los talones todo lo posible y aprieta las pantorrillas.",
      "Baja lentamente hasta sentir estiramiento.",
    ],
    consejos: [
      "Evita rebotar; haz una pausa arriba.",
      "Mantén las rodillas ligeramente flexionadas y el core activo.",
    ],
  },
  "Elevación de talones sentado": {
    demo: "Seated_Calf_Raise",
    pasos: [
      "Siéntate con las rodillas bajo las almohadillas y los pies en la plataforma.",
      "Sube los talones y aprieta las pantorrillas.",
      "Baja controlado hasta estirar el músculo.",
    ],
    consejos: [
      "No uses impulso con el torso.",
      "Trabaja con un rango completo y pausa en la contracción.",
    ],
  },
  "Press de banca plano con barra": {
    demo: "Barbell_Bench_Press_-_Medium_Grip",
    pasos: [
      "Acuéstate en el banco, pies firmes y escápulas retraídas.",
      "Baja la barra al pecho con los codos a unos 45°.",
      "Empuja hasta extender los brazos sin rebotar.",
    ],
    consejos: [
      "Mantén las muñecas rectas y la barra alineada con el antebrazo.",
      "Usa un agarre que te permita bajar la barra con control.",
    ],
  },
  "Press inclinado con mancuernas": {
    demo: "Incline_Dumbbell_Press",
    pasos: [
      "Ajusta el banco a unos 30-45° y apoya bien la espalda.",
      "Baja las mancuernas a los lados del pecho superior.",
      "Empuja hacia arriba y ligeramente hacia dentro.",
    ],
    consejos: [
      "No juntes las mancuernas de golpe arriba.",
      "Mantén los codos por debajo de los hombros.",
    ],
  },
  "Press de banca plano con mancuernas": {
    demo: "Dumbbell_Bench_Press",
    pasos: [
      "Acuéstate con una mancuerna en cada mano y los pies firmes.",
      "Baja controlado hasta que los codos queden a la altura del torso.",
      "Empuja hacia arriba sin perder la posición de los hombros.",
    ],
    consejos: [
      "Evita abrir demasiado los codos.",
      "Controla la bajada; no dejes caer las mancuernas.",
    ],
  },
  "Aperturas en polea": {
    demo: "Cable_Crossover",
    pasos: [
      "Colócate entre las poleas con un pie adelantado y el torso ligeramente inclinado.",
      "Con los codos semiflexionados, lleva las manos hacia el centro.",
      "Aprieta el pecho y vuelve controlando la apertura.",
    ],
    consejos: [
      "No conviertas el movimiento en un press; mantén los codos fijos.",
      "Usa un peso que te permita sentir el estiramiento sin perder la postura.",
    ],
  },
  "Fondos en paralelas": {
    demo: "Dips_-_Chest_Version",
    pasos: [
      "Sujétate en las paralelas con los brazos extendidos.",
      "Baja flexionando los codos hasta sentir estiramiento en el pecho.",
      "Empuja para volver arriba sin encoger los hombros.",
    ],
    consejos: [
      "Inclina el torso hacia delante para enfatizar el pecho.",
      "Si te molestan los hombros, limita la profundidad.",
    ],
  },
  "Flexiones de pecho": {
    demo: "Pushups",
    pasos: [
      "Coloca las manos un poco más anchas que los hombros y el cuerpo alineado.",
      "Baja el pecho manteniendo el core firme.",
      "Empuja el suelo hasta extender los brazos.",
    ],
    consejos: [
      "No dejes caer la cadera ni subas la cabeza.",
      "Puedes apoyar las rodillas para mantener la técnica.",
    ],
  },
  Dominadas: {
    demo: "Pullups",
    pasos: [
      "Cuélgate de la barra con agarre prono y los hombros activos.",
      "Tira de los codos hacia abajo hasta superar la barbilla.",
      "Baja controlado hasta extender los brazos.",
    ],
    consejos: [
      "Evita balancearte; usa el core para estabilizar.",
      "Trabaja la fuerza con bandas o dominadas negativas si es necesario.",
    ],
  },
  "Jalón al pecho": {
    demo: "Wide-Grip_Lat_Pulldown",
    pasos: [
      "Siéntate con los muslos bajo las almohadillas y agarra la barra.",
      "Lleva la barra hacia la parte superior del pecho llevando los codos abajo.",
      "Vuelve arriba controlando el estiramiento.",
    ],
    consejos: [
      "No tires la barra por detrás de la nuca.",
      "Evita usar impulso con el torso; mantén el pecho alto.",
    ],
  },
  "Remo con barra": {
    demo: "Bent_Over_Barbell_Row",
    pasos: [
      "Inclina el torso con la espalda neutra y la barra colgando.",
      "Tira de la barra hacia el abdomen bajo llevando los codos atrás.",
      "Baja controlado sin perder la posición.",
    ],
    consejos: [
      "No redondees la espalda ni uses el impulso de la cadera.",
      "Aprieta las escápulas al final del recorrido.",
    ],
  },
  "Remo con mancuerna a una mano": {
    demo: "One-Arm_Dumbbell_Row",
    pasos: [
      "Apoya una mano y una rodilla en el banco con la espalda plana.",
      "Tira de la mancuerna hacia la cadera.",
      "Baja controlado hasta extender el brazo.",
    ],
    consejos: [
      "Mantén el torso estable y evita rotar la cadera.",
      "Lleva el codo hacia atrás, no hacia fuera.",
    ],
  },
  "Remo en polea baja / Gironda": {
    demo: "Seated_Cable_Rows",
    pasos: [
      "Siéntate con los pies apoyados y agarra el maneral.",
      "Tira hacia el abdomen llevando los codos atrás.",
      "Vuelve controlado manteniendo el pecho alto.",
    ],
    consejos: [
      "No te eches hacia atrás para mover más peso.",
      "Siente el trabajo en la espalda media, no solo en los brazos.",
    ],
  },
  Pullover: {
    demo: "Bent-Arm_Dumbbell_Pullover",
    pasos: [
      "Acuéstate en el banco con una mancuerna sujeta con ambas manos.",
      "Lleva la mancuerna por detrás de la cabeza con los codos semiflexionados.",
      "Vuelve arriba controlando el recorrido.",
    ],
    consejos: [
      "No fuerces el rango si sientes molestia en el hombro.",
      "Mantén las costillas abajo y evita arquear la lumbar.",
    ],
  },
  "Press militar": {
    demo: "Standing_Military_Press",
    pasos: [
      "De pie con la barra a la altura de los hombros y el core activo.",
      "Empuja la barra hacia arriba hasta extender los brazos.",
      "Baja controlado hasta la posición inicial.",
    ],
    consejos: [
      "No arquees la espalda para empujar; aprieta glúteos y abdominales.",
      "Pasa la cabeza ligeramente hacia delante al final del empuje.",
    ],
  },
  "Press de hombros sentado con mancuernas": {
    demo: "Dumbbell_Shoulder_Press",
    pasos: [
      "Siéntate con la espalda apoyada y las mancuernas a la altura de los hombros.",
      "Empuja hacia arriba hasta casi extender los codos.",
      "Baja controlado sin perder la posición.",
    ],
    consejos: [
      "Evita bloquear los codos de golpe.",
      "Mantén las muñecas alineadas y los codos debajo de las manos.",
    ],
  },
  "Elevaciones laterales": {
    demo: "Side_Lateral_Raise",
    pasos: [
      "De pie con mancuernas a los lados y los codos ligeramente flexionados.",
      "Eleva los brazos hasta la altura de los hombros.",
      "Baja controlado sin balancear el cuerpo.",
    ],
    consejos: [
      "No subas los hombros hacia las orejas.",
      "Usa un peso ligero y prioriza la técnica.",
    ],
  },
  Pájaros: {
    demo: "Reverse_Flyes",
    pasos: [
      "Inclina el torso con la espalda neutra y las mancuernas colgando.",
      "Eleva los brazos hacia los lados manteniendo los codos semiflexionados.",
      "Baja controlado sintiendo el deltoides posterior.",
    ],
    consejos: [
      "No uses impulso con el torso.",
      "Mantén el cuello relajado y las escápulas estables.",
    ],
  },
  "Face pulls": {
    demo: "Face_Pull",
    pasos: [
      "Ajusta la polea a la altura de la cara y agarra la cuerda.",
      "Tira de la cuerda hacia la frente separando las manos.",
      "Vuelve controlado manteniendo los hombros abajo.",
    ],
    consejos: [
      "Aprieta la espalda alta al final del movimiento.",
      "Evita echar la cabeza hacia atrás.",
    ],
  },
  "Curl de bíceps con barra": {
    demo: "Barbell_Curl",
    pasos: [
      "De pie con la barra en pronación y los codos pegados al torso.",
      "Flexiona los codos llevando la barra hacia los hombros.",
      "Baja controlado hasta extender los brazos.",
    ],
    consejos: [
      "No balancees el torso para subir el peso.",
      "Mantén las muñecas neutras y los codos quietos.",
    ],
  },
  "Curl de bíceps inclinado": {
    demo: "Incline_Dumbbell_Curl",
    pasos: [
      "Siéntate en un banco inclinado con los brazos colgando.",
      "Flexiona los codos llevando las mancuernas hacia los hombros.",
      "Baja controlando el estiramiento.",
    ],
    consejos: [
      "Mantén los hombros atrás y el pecho apoyado.",
      "No subas los codos hacia delante.",
    ],
  },
  "Curl de bíceps alterno": {
    demo: "Dumbbell_Alternate_Bicep_Curl",
    pasos: [
      "De pie con mancuernas a los lados y los codos pegados.",
      "Flexiona un codo llevando la mancuerna al hombro.",
      "Baja y repite con el otro brazo.",
    ],
    consejos: [
      "Evita girar el torso para ayudar.",
      "Controla la bajada en cada repetición.",
    ],
  },
  "Curl martillo": {
    demo: "Hammer_Curls",
    pasos: [
      "De pie con mancuernas y agarre neutro.",
      "Flexiona los codos manteniendo las palmas enfrentadas.",
      "Baja controlado hasta extender los brazos.",
    ],
    consejos: [
      "Mantén los codos cerca del torso.",
      "No uses impulso ni balanceo.",
    ],
  },
  "Plancha abdominal": {
    demo: "Plank",
    pasos: [
      "Apoya antebrazos y puntas de los pies con el cuerpo alineado.",
      "Aprieta glúteos y abdominales para mantener la posición.",
      "Respira de forma constante sin dejar caer la cadera.",
    ],
    consejos: [
      "No eleves la cadera ni la dejes hundirse.",
      "Ajusta el tiempo a tu capacidad y mantén la técnica.",
    ],
  },
  Crunches: {
    demo: "Crunches",
    pasos: [
      "Acuéstate boca arriba con las rodillas flexionadas y los pies apoyados.",
      "Eleva la parte superior de la espalda contrayendo el abdomen.",
      "Baja controlado sin tirar del cuello.",
    ],
    consejos: [
      "No juntes las manos detrás de la nuca con fuerza.",
      "Exhala al subir y evita usar impulso.",
    ],
  },
  "Crunch invertido": {
    demo: "Reverse_Crunch",
    pasos: [
      "Acuéstate con las piernas elevadas y las rodillas flexionadas.",
      "Eleva la pelvis hacia el pecho contrayendo el abdomen.",
      "Baja controlado sin arquear la lumbar.",
    ],
    consejos: [
      "El movimiento es corto; no balances las piernas.",
      "Mantén las manos apoyadas para estabilizar.",
    ],
  },
  "Elevación de piernas colgado": {
    demo: "Hanging_Leg_Raise",
    pasos: [
      "Cuélgate de la barra con los hombros activos y el cuerpo estable.",
      "Eleva las piernas rectas o flexionadas hasta donde controles.",
      "Baja lentamente sin balancearte.",
    ],
    consejos: [
      "Evita usar impulso; controla el descenso.",
      "Si te cuesta, comienza con rodillas flexionadas.",
    ],
  },
  "Abdominales bicicleta": {
    demo: "Air_Bike",
    pasos: [
      "Acuéstate boca arriba y eleva las piernas con las rodillas flexionadas.",
      "Lleva un codo hacia la rodilla opuesta girando el torso.",
      "Alterna los lados con control y respiración constante.",
    ],
    consejos: [
      "No tires del cuello.",
      "Mantén la lumbar cerca del suelo y evita ir demasiado rápido.",
    ],
  },
  "Extensión de tríceps en polea": {
    demo: "Triceps_Pushdown",
    pasos: [
      "Colócate frente a la polea alta y agarra la barra o cuerda.",
      "Extiende los codos llevando las manos hacia abajo.",
      "Vuelve controlado manteniendo los codos pegados al torso.",
    ],
    consejos: [
      "No muevas los hombros ni el torso.",
      "Aprieta el tríceps al final del recorrido.",
    ],
  },
  "Copa de tríceps": {
    demo: "Seated_Triceps_Press",
    pasos: [
      "Siéntate con una mancuerna sujeta con ambas manos sobre la cabeza.",
      "Baja la mancuerna por detrás de la cabeza flexionando los codos.",
      "Extiende los codos para volver arriba.",
    ],
    consejos: [
      "Mantén los codos apuntando al frente y cerca de la cabeza.",
      "No arquees la espalda para ayudar.",
    ],
  },
  "Press francés": {
    demo: "Lying_Triceps_Press",
    pasos: [
      "Acuéstate en un banco con la barra Z sobre la frente.",
      "Flexiona los codos bajando la barra hacia la cabeza.",
      "Extiende los codos sin mover los hombros.",
    ],
    consejos: [
      "Mantén los codos quietos y apuntando arriba.",
      "Usa un peso moderado para cuidar los codos.",
    ],
  },
  "Fondos en paralelas (Tríceps)": {
    demo: "Dips_-_Triceps_Version",
    pasos: [
      "Sujétate en las paralelas con el torso más vertical.",
      "Baja flexionando los codos pegados al cuerpo.",
      "Empuja para extender los brazos sin encoger los hombros.",
    ],
    consejos: [
      "No bajes más allá de lo que controlas.",
      "Mantén los codos cerca del torso para enfatizar tríceps.",
    ],
  },
};
