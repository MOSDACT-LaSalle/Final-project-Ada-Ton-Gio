//OSC-------------------------------------
import oscP5.*;
import netP5.*;

OscP5 oscP5;  // Para recibir mensajes OSC
NetAddress remoteLocation;  // Dirección para enviar mensajes OSC
boolean mouseIsPressed = false;  // Estado del clic simulado
PVector touchPos = new PVector();  // Posición actual del tacto

//AUDIO------------------------------------

import ddf.minim.*;  
import ddf.minim.analysis.*;

Minim minim;
AudioPlayer player;  // Audio input stream to capture microphone input
FFT fft;  // For frequency analysis
float amplitude;  // Variable to store the current amplitude
float beatEnergy; // Energy in the lower frequencies

// VISUALES
int ESCENA = 3;

// VARIABLES SETAS
int numParticulas = 200;  // Número total de partículas
Particle[] particulas = new Particle[numParticulas];  // Array para almacenar las partículas

// VARIABLES SEPARATION FINAL
int numLines = 200;   // Number of lines for a more dense, waterfall-like effect
float timeOffset = 0.0;  // Time for animating the flow
float holeRadiusX = 20;  // Width of the oval for horizontal displacement
float holeRadiusY = 30;   // Height of the oval for vertical displacement
float separationStrength = 30;  // Strength of the separation effect

// VARIABLES TON
ArrayList<Particula> particulast;
ArrayList<PuntoInvisible> puntosInvisibles; // Para almacenar puntos invisibles
color[] colores; // Array de colores para el gradiente
int numColores = 200; // Número de colores en el gradiente
int pulsoIntervalo = 500; // Intervalo del pulso en milisegundos (120 BPM)
int ultimoPulso = 0; // Marca de tiempo del último pulso

void setup() {
  //size(600, 800);  // Tamaño de la ventana
  fullScreen();
  
  //OSC------------------
  // Inicializamos oscP5 para recibir mensajes en el puerto 12000
  oscP5 = new OscP5(this, 10001);
  
  // Dirección remota para enviar datos OSC (puede ser localhost para pruebas)
  remoteLocation = new NetAddress("127,0,0,1", 10001);  // Cambia "192.168.1.50" por la IP del receptor y "12001" por el puerto que escuchará el receptor OSC

  //AUDIO-------
  minim = new Minim(this);
  player = minim.loadFile ("neon-waves.mp3", 1024);
  player.play();
  
  fft = new FFT(player.bufferSize(), player.sampleRate());
  
  // SETAS
  colorMode(HSB, 360, 100, 100);  // Usamos HSB para manejar colores pastel
  for (int i = 0; i < numParticulas; i++) {
    particulas[i] = new Particle();  // Inicializar cada partícula
  }
  // SEPARATION
  strokeCap(ROUND);  // Smooth ends of strokes
  // TON
  particulast = new ArrayList<Particula>();
  puntosInvisibles = new ArrayList<PuntoInvisible>();

  // Crear un gradiente suave de colores entre varios tonos de verde
  colores = new color[numColores];
  for (int i = 0; i < numColores; i++) {
    float inter = map(i, 0, numColores, 0, 1);
    colores[i] = lerpColor(color(0, 100, 0), color(144, 238, 144), inter); // De verde oscuro a verde claro
  }
  
}

void draw() {
  fft.forward(player.mix);  // Analizar el audio
  amplitude = player.mix.level() * 800;  // Obtener la amplitud
  beatEnergy = fft.calcAvg(4000, 4000);  // Obtener la energía de las frecuencias bajas (para el ritmo)

  if (ESCENA == 1) { // SETAS
    colorMode(HSB, 360, 100, 100);
    background(0);  // Fondo negro

    for (int i = 0; i < numParticulas; i++) {
      particulas[i].update();  // Actualizar posición de la partícula
      particulas[i].display();  // Dibujar la partícula
      particulas[i].checkEdges();  // Verificar si la partícula ha salido de la pantalla
    }
  }
  if (ESCENA == 2) { // SEPARATION
    colorMode(RGB);
    background(0, 50);  // Semi-transparent background to create the trailing effect

    for (int i = 0; i < numLines; i++) {
      float startX = i * (width / numLines);
      drawFlowingLine(startX, timeOffset + i * 0.05);  // Lines are offset in time for smoother motion
    }

    // Ajustar la velocidad del desplazamiento temporal según la música
    timeOffset += 0.01 + amplitude * 0.002;  // Más amplitud = más rápido el movimiento
  }
  if (ESCENA == 3) {
    colorMode(RGB);
    background(0);

    // Crear varias partículas menos explosivas cuando el ratón esté presionado
    if (mousePressed) {
      for (int i = 0; i < 6; i++) { // Generar 6 partículas por ciclo
        particulast.add(new Particula(mouseX, mouseY));
      }
    }

    // Pulso blanco sincronizado con el ritmo
    int tiempoActual = millis();
    boolean esPulso = beatEnergy > 0.5;  // Detectar un golpe fuerte en las frecuencias bajas

    // Dibujar y actualizar las partículas
    for (int i = particulast.size() - 1; i >= 0; i--) {
      Particula p = particulast.get(i);
      p.update();

      // Calcular el color de la partícula
      float lifeRatio = map(p.lifespan, 0, 100, 0, 1);
      int colorIndex = int(lifeRatio * (numColores - 1));
      colorIndex = constrain(colorIndex, 0, numColores - 1); // Asegurar que no salga del rango

      // Si está en pulso, hacer que el color sea blanco
      if (esPulso) {
        p.show(color(0, 100, 0), true); // Mostrar blanco puro en pulso
      } else {
        // Transición gradual a su color original tras el pulso
        float fade = map(tiempoActual - ultimoPulso, 0, 255, 0, 0.2); // Desvanece de blanco a color original
        color currentColor = lerpColor(color(255), colores[colorIndex], constrain(fade / 255.0, 0, 1));
        p.show(currentColor, false);
      }

      // Eliminar la partícula si su vida se acaba
      if (p.isDead()) {
        // 1% de probabilidad de crear un punto invisible
        if (random(1) < 0.01) {
          puntosInvisibles.add(new PuntoInvisible(p.pos.x, p.pos.y));
        }
        particulast.remove(i);
      }
    }

    // Dibujar líneas entre los puntos invisibles con efecto de relámpago
    for (int i = 0; i < puntosInvisibles.size(); i++) {
      PuntoInvisible puntoA = puntosInvisibles.get(i);
      for (int j = i + 1; j < puntosInvisibles.size(); j++) {
        PuntoInvisible puntoB = puntosInvisibles.get(j);
        color relampagoColor = calcularColorRelampago(puntoA); // Calcular color según el tiempo en pantalla
        dibujarRelampago(puntoA.pos, puntoB.pos, relampagoColor); // Dibujar líneas estilo relámpago
      }

      // Actualizar los puntos invisibles y eliminarlos después de 3 segundos
      puntoA.update();
      if (puntoA.isDead()) {
        puntosInvisibles.remove(i);
        i--; // Ajustar el índice después de eliminar un elemento
      }
    }
  }
}


// SETAS ---------------
// Clase Particle para manejar cada partícula individualmente
class Particle {
  float x, y;  // Posición de la partícula
  float startX, startY;  // Posición inicial de la partícula (en la parte inferior)
  float speedX, speedY;  // Velocidades en los ejes X e Y
  float size;  // Tamaño de la partícula
  color startColor, endColor;  // Colores para el degradado (blanco -> pastel)

  Particle() {
    startX = random(width);  // Posición horizontal aleatoria en la parte inferior
    startY = height;  // Inicia en la parte inferior de la pantalla
    x = startX;
    y = startY;
    speedX = random(-1, 1);  // Velocidad horizontal leve aleatoria
    speedY = random(2, 5) + amplitude * 2;  // Velocidad vertical hacia arriba
    size = random(3, 8) + amplitude * 0.1;  // Tamaño aleatorio de la partícula

    // Color inicial (blanco)
    startColor = color(0, 0, 100);  // Blanco en modo HSB

    // Color final aleatorio pastel (colores con bajo nivel de saturación y alto brillo)
    float hue = random(0, 360);  // Matiz aleatorio
    endColor = color(hue, random(30, 60), 100);  // Colores pastel aleatorios (baja saturación, alto brillo)
  }

  void update() {
    x += speedX;  // Actualizar posición horizontal
    y -= speedY;  // Subir la partícula
  }

  void display() {
    noStroke();

    // Calcular el progreso de la partícula (desde la parte inferior hasta su posición actual)
    float progress = map(y, height, 0, 0, 1);

    // Interpolar el color entre blanco y el color pastel
    color currentColor = lerpColor(startColor, endColor, progress);

    // Dibujar la partícula
    fill(currentColor);
    ellipse(x, y, size, size);  // Dibujar la partícula como un círculo

    // Dibujar la estela que va desde la parte inferior hasta la posición actual
    stroke(currentColor);
    strokeWeight(1);  // Grosor de la estela
    line(startX, startY, x, y);  // Línea desde la parte inferior hasta la posición actual de la partícula
  }

  void checkEdges() {
    // Si la partícula sale por la parte superior, la reiniciamos en la parte inferior
    if (y < 0) {
      startX = random(width);  // Reiniciar posición inicial horizontal
      startY = height;  // Reiniciar posición en la parte inferior
      x = startX;
      y = startY;
      speedX = random(-1, 1);
      speedY = random(2, 5);
      size = random(3, 8);

      // Generar nuevos colores pastel
      float hue = random(0, 360);
      endColor = color(hue, random(30, 60), 100);  // Nuevo color pastel
    }
  }
}

// SEPARATION ------

void drawFlowingLine(float startX, float tOffset) {
  float prevX = startX;
  float prevY = 0;

  for (float y = 0; y < height; y += 5) {
    // Calculate distance from the current point to the mouse, scaled for an oval effect
    float distX = abs(startX - mouseX) / holeRadiusX;
    float distY = abs(y - mouseY) / holeRadiusY;

    // Combined distance factor for the oval effect
    float distToMouse = sqrt(sq(distX) + sq(distY));

    // Create a strong separation effect when the mouse is close, based on oval distance
    float separationEffect = 0;

    if (distToMouse < 1) {
      // Push the line away from the mouse, much stronger effect within the oval shape
      separationEffect = map(distToMouse, 0, 1, separationStrength, 0);
    }

    // Adjust the noise function for grid flow
    float n = noise(startX * 0.01, y * 0.01, tOffset);
    float xOff = map(n, 0, 1, -30, 30);  // Normal flowing motion

    // Apply the separation effect with oval scaling
    float finalX = startX + xOff + separationEffect * (startX > mouseX ? 1 : -1);

    float alpha = map(y, 0, height, 255, 0);  // Fading effect from top to bottom

    // Gradient colors transitioning as the lines fall (warm to cool tones)
    float red = map(y, 0, height, 255, 50);
    float green = map(y, 0, height, 100, 20);
    float blue = map(y, 0, height, 50, 100);

    stroke(red, green, blue, alpha);  // Apply the color and fading effect
    strokeWeight(map(n, 0, 1, 1, 3));  // Varying stroke weights based on noise

    line(prevX, prevY, finalX, y);  // Draw the flowing line with strong separation effect
    prevX = finalX;
    prevY = y;
  }
}

// TON ------------------------
// Función para calcular el color del relámpago según el tiempo en pantalla
color calcularColorRelampago(PuntoInvisible punto) {
  float tiempoEnPantalla = millis() - punto.creationTime; // Tiempo en pantalla en milisegundos
  float ratio = map(tiempoEnPantalla, 0, 3000, 0, 1); // Mapa de 0 a 1 en 3 segundos
  ratio = constrain(ratio, 0, 1); // Asegurar que esté en el rango de 0 a 1

  // Colores de degradado de naranja a rojo
  color naranja = color(255, 165, 0); // Naranja
  color rojo = color(255, 0, 0); // Rojo
  return lerpColor(naranja, rojo, ratio); // Degradado
}

// Función para dibujar un "relámpago" entre dos puntos
void dibujarRelampago(PVector start, PVector end, color relampagoColor) {
  float segmentLength = dist(start.x, start.y, end.x, end.y) / 10; // Dividir en segmentos
  PVector currentPoint = start.copy();

  for (int i = 0; i < 10; i++) {
    // Generar el próximo punto con un pequeño desplazamiento aleatorio
    PVector nextPoint = PVector.lerp(currentPoint, end, 0.1); // Avanza un 10% hacia el final
    nextPoint.x += random(-10, 10); // Variación aleatoria en X
    nextPoint.y += random(-10, 10); // Variación aleatoria en Y

    // Dibujar un segmento de línea
    strokeWeight(random(1, 2)); // Variar el grosor de los segmentos
    stroke(relampagoColor); // Usar el color calculado para el relámpago
    line(currentPoint.x, currentPoint.y, nextPoint.x, nextPoint.y);

    currentPoint = nextPoint; // Actualizar el punto actual
  }

  // Dibujar el último segmento hasta el punto final
  line(currentPoint.x, currentPoint.y, end.x, end.y);
}

class Particula {
  PVector pos, vel, acc;
  float lifespan;
  float size; // Tamaño inicial de la partícula
  float angleOffset; // Offset para movimiento sinusoidal

  Particula(float x, float y) {
    pos = new PVector(x, y);
    vel = PVector.random2D().mult(random(1, 3)); // Velocidad inicial más suave
    acc = new PVector();
    lifespan = 255; // Vida útil de la partícula
    size = random(6, 10); // Tamaño inicial más grande
    angleOffset = random(TWO_PI); // Offset aleatorio para movimiento sinuoso
  }

  // Actualizar la posición y aplicar fuerzas para que siga el ratón
  void update() {
    PVector mouse = new PVector(mouseX, mouseY);
    PVector dir = PVector.sub(mouse, pos); // Dirección hacia el ratón
    dir.setMag(0.05); // Controlar la atracción al ratón
    acc.add(dir); // Agregar la aceleración

    vel.add(acc);
    vel.limit(4); // Limitar la velocidad máxima

    // Movimiento sinusoidal para hacerlo más orgánico
    float sinWave = sin(frameCount * 0.1 + angleOffset) * 0.5;
    pos.x += sinWave; // Oscilación en la posición X
    pos.add(vel);

    acc.mult(0); // Resetear aceleración
    lifespan -= 3.0; // Reducir la vida más rápido
  }

  // Mostrar la partícula con el color actual
  void show(color c, boolean isPulso) {
    if (isPulso) {
      strokeWeight(2); // Hacerlas más brillantes durante el pulso
    } else {
      strokeWeight(1);
    }

    // Ajustar el tamaño según la vida útil de la partícula
    float sizeActual = map(lifespan, 0, 255, 0, size); // El tamaño se reduce conforme la vida disminuye
    stroke(c, lifespan);
    noFill();

    // Dibujar una cruz en lugar de un círculo
    line(pos.x - sizeActual, pos.y, pos.x + sizeActual, pos.y); // Línea horizontal
    line(pos.x, pos.y - sizeActual, pos.x, pos.y + sizeActual); // Línea vertical
  }

  // Verificar si la partícula está "muerta"
  boolean isDead() {
    return lifespan <= 0;
  }
}

class PuntoInvisible {
  PVector pos;
  float creationTime;

  PuntoInvisible(float x, float y) {
    pos = new PVector(x, y);
    creationTime = millis(); // Tiempo de creación
  }

  // Actualizar el punto invisible
  void update() {
    // No hay cambios visuales en los puntos invisibles
  }

  // Verificar si han pasado 3 segundos desde su creación
  boolean isDead() {
    return millis() - creationTime > 3000; // 3 segundos
  }
}

void keyPressed () {
  if (key == '1') {
    ESCENA = 1;
  }
  if (key == '2') {
    ESCENA = 2;
  }
  if (key == '3') {
    ESCENA = 3;
  }
}

void oscEvent(OscMessage msg) {
  if (msg.checkAddrPattern("/touch") == true) {  // Si el mensaje es de tipo "touch"
    float x = msg.get(0).floatValue();  // Coordenada X del toque
    float y = msg.get(1).floatValue();  // Coordenada Y del toque
    boolean isTouching = msg.get(2).intValue() == 1;  // Si está tocando o no (1 para tocar, 0 para soltar)
    
    touchPos.set(x, y);  // Actualizar la posición del toque

    // Simular el clic y arrastre según los datos recibidos
    if (isTouching && !mouseIsPressed) {
      simulateMousePress();
      mouseIsPressed = true;
    } else if (!isTouching && mouseIsPressed) {
      simulateMouseRelease();
      mouseIsPressed = false;
    }
  }
}

// Simular la presión del mouse
void simulateMousePress() {
  // Enviar un mensaje OSC de "mousePressed"
  OscMessage msg = new OscMessage("/mousePressed");
  msg.add(touchPos.x);  // Posición X
  msg.add(touchPos.y);  // Posición Y
  oscP5.send(msg, remoteLocation);  // Enviar al destino OSC
  println("Mouse pressed at: " + touchPos);
}

// Simular la liberación del mouse
void simulateMouseRelease() {
  // Enviar un mensaje OSC de "mouseReleased"
  OscMessage msg = new OscMessage("/mouseReleased");
  msg.add(touchPos.x);  // Posición X
  msg.add(touchPos.y);  // Posición Y
  oscP5.send(msg, remoteLocation);  // Enviar al destino OSC
  println("Mouse released at: " + touchPos);
}
