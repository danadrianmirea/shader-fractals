/*
(PT - Br) Documentação em português começa na linha 6.
(En) English documentation starts on line 32.

(PT - Br)
Documentação em português:
Este é um shader voltado para a renderização matemática do Cogumelo de Menger, um fractal baseado na
mais conhecida Esponja de Menger, uma generalização para maiores dimensões do Carpete de Sierpinski.

Para a construção desse shader foram utilizadas diversas fontes:
A fonte mais relevante para essa produção foi o trabalho de Inigo Quilez em fórmulas de SDFs e em
demonstrações de RayMarching. Todas as outras fontes que serão citadas também o citam como fonte.
- Inigo Quilez : http://iquilezles.org​
- Sebastian Lague: https://www.youtube.com/user/Cercopithecan
- CodeParade: https://www.youtube.com/channel/UCrv269YwJzuZL3dH5PCgxUw

Este shader está sob a licença MIT.
Cheque "License.txt" para detalhes sobre a licensa.

Caso não queira compilar este shader você mesmo, siga esse link para ver ele funcionando:
<este link não existe ainda, será adicionado nos próximos dias>

Instruções para compilar:
- Entre no site https://www.shadertoy.com
- No canto superior direito, clique em "new". Você será redirecionado para uma página com uma caixa
de texto onde voce pode escrever e uma tela.
- Apague todo o conteúdo da caixa de texto.
- Copie este código e cole-o diretamente na ciaxa de texto.
- Se nada mudar, aperte "alt" + "enter" e o shader deve compilar.

(En)
English documentation:
This shader targets to achieve a mathematical render of Menger's Mushroom, a fractal based on the more
famous Menger's Sponge, a generalization to higher dimensions of Sierpinski's Carpet.

For the creation of this shader, several resources were used:
The most relevant resource is certainly Inigo Quilez's work on SDFs (Signed Distance Fields) and his
works on RayMarching. All other resources also cite him as a resource.
- Inigo Quilez : http://iquilezles.org​
- Sebastian Lague: https://www.youtube.com/user/Cercopithecan
- CodeParade: https://www.youtube.com/channel/UCrv269YwJzuZL3dH5PCgxUw

This shader in under the MIT license.
Refer to "LICENSE.txt" for the details of the license.

If you don't want to compile this shader yourself, you can follow this link to see it working:
<this link does not exist yet, but will be added in the following days>

Instructions to compile:
- Follow this url: https://www.shadertoy.com.
- On the upper right portion of the screen, click on the "new" button. You will be redirected to a page
with a text box you can write on and a screen.
- Delete all the text on the text box.
- Copy this code and paste it on the text box.
- If nothing happnes, press "alt" + "enter" and the shader should compile.
*/

#define MaximumRaySteps 100
#define MaximumDistance 1000.
#define MinimumDistance .01
#define PI 3.141592653589793238

// --------------------------------------------------------------------------------------------//
// SDF FUNCTIONS //

// Sphere
// s: radius
float SignedDistSphere (vec3 p, float s) {
  return length (p) - s;
}

// Box
// b: size of box in x/y/z
float SignedDistBox (vec3 p, vec3 b) {
  vec3 d = abs (p) - b;
  return min (max (d.x, max (d.y, d.z)), 0.0) + length (max (d, 0.0));
}

// (Infinite) Plane
// n.xyz: normal of the plane (normalized)
// n.w: offset from origin
float SignedDistPlane (vec3 p, vec4 n) {
  return dot (p, n.xyz) + n.w;
}

// Rounded box
// r: radius of the rounded edges
float SignedDistRoundBox (in vec3 p, in vec3 b, in float r) {
  vec3 q = abs (p) - b;
  return min (max (q.x, max (q.y, q.z)), 0.0) + length (max (q, 0.0)) - r;
}

// BOOLEAN OPERATORS //

// Union
// d1: signed distance to shape 1
// d2: signed distance to shape 2
float opU (float d1, float d2) {
  return (d1 < d2) ? d1 : d2;
}

// Subtraction
// d1: signed distance to shape 1
// d2: signed distance to shape 2
vec4 opS (vec4 d1, vec4 d2) {
  return (-d1.w > d2.w) ? -d1 : d2;
}

// Intersection
// d1: signed distance to shape 1
// d2: signed distance to shape 2
vec4 opI (vec4 d1, vec4 d2) {
  return (d1.w > d2.w) ? d1 : d2;
}

// Mod Position Axis
float pMod1 (inout float p, float size) {
  float halfsize = size * 0.5;
  float c = floor ((p + halfsize) / size);
  p = mod (p + halfsize, size) - halfsize;
  p = mod (-p + halfsize, size) - halfsize;
  return c;
}

// SMOOTH BOOLEAN OPERATORS //

// Smooth Union
// d1: signed distance to shape 1
// d2: signed distance to shape 2
// k: smoothness value for the trasition
float opUS (float d1, float d2, float k) {
  float h = clamp (0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
  float dist = mix (d2, d1, h) - k * h * (1.0 - h);

  return dist;
}

// Smooth Subtraction
// d1: signed distance to shape 1
// d2: signed distance to shape 2
// k: smoothness value for the trasition
vec4 opSS (vec4 d1, vec4 d2, float k) {
  float h = clamp (0.5 - 0.5 * (d2.w + d1.w) / k, 0.0, 1.0);
  float dist = mix (d2.w, -d1.w, h) + k * h * (1.0 - h);
  vec3 color = mix (d2.rgb, d1.rgb, h);

  return vec4 (color.rgb, dist);
}

// Smooth Intersection
// d1: signed distance to shape 1
// d2: signed distance to shape 2
// k: smoothness value for the trasition
vec4 opIS (vec4 d1, vec4 d2, float k) {
  float h = clamp (0.5 - 0.5 * (d2.w - d1.w) / k, 0.0, 1.0);
  float dist = mix (d2.w, d1.w, h) + k * h * (1.0 - h);
  vec3 color = mix (d2.rgb, d1.rgb, h);

  return vec4 (color.rgb, dist);
}

// TRANSFORM FUNCTIONS //

mat2 Rotate (float angle) {
  float s = sin (angle);
  float c = cos (angle);

  return mat2 (c, -s, s, c);
}

vec3 R (vec2 uv, vec3 p, vec3 l, float z) {
  vec3 f = normalize (l - p),
    r = normalize (cross (vec3 (0, 1, 0), f)),
    u = cross (f, r),
    c = p + f * z,
    i = c + uv.x * r + uv.y * u,
    d = normalize (i - p);
  return d;
}

// --------------------------------------------------------------------------------------------//
vec3 hsv2rgb (vec3 c) {
  vec4 K = vec4 (1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs (fract (c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix (K.xxx, clamp (p - K.xxx, 0.0, 1.0), c.y);
}

float map (float value, float min1, float max1, float min2, float max2) {
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

float sierpinski3 (out vec3 z) {
  vec2 mouse = iMouse.xy / iResolution.xy;
  float iterations = 25.0;
  float Scale = 2.0 + (sin (iTime / 5.0) + 1.0);
  vec3 Offset = 3.0 * vec3 (1.0, 1.0, 1.0);
  float bailout = 1000.0;

  float r = length (z);
  int n = 0;
  while (n < int (iterations) && r < bailout) {
    //z.yz *= Rotate (map (sin (iTime / 2.0), -1.0, 1.0, 0.0, 2.0) * PI);
    z.yx *= Rotate (sin (iTime / 5.0));
    //z.yx *= Rotate (0.436332);
    //z.yx *= Rotate (PI / 10.0);
    //z.xz *= Rotate(map(sin(iTime / 2.0), -1.0, 1.0, 0.0, 2.0) * PI);

    z.x = abs (z.x);
    z.y = abs (z.y);
    z.z = abs (z.z);

    if (z.x - z.y < 0.0) z.xy = z.yx; // fold 1
    if (z.x - z.z < 0.0) z.xz = z.zx; // fold 2
    if (z.y - z.z < 0.0) z.zy = z.yz; // fold 3

    z.yz *= Rotate (sin (iTime / 2.0) / 2.0);
    //z.yx *= Rotate (sin (iTime / 2.0) / 5.0);
    //z.yx *= Rotate(-map(mouse.x, -1.0, 1.0, 0.0, 2.0));
    //z.xz *= Rotate (0.4336332 + 0.02 * iTime);
    //z.yx *= Rotate (PI / 10.0);
    z.xz *= Rotate (sin (iTime / 2.0) / 5.0);

    z.x = z.x * Scale - Offset.x * (Scale - 1.0);
    z.y = z.y * Scale - Offset.y * (Scale - 1.0);
    z.z = z.z * Scale;

    if (z.z > 0.5 * Offset.z * (Scale - 1.0)) {
      z.z -= Offset.z * (Scale - 1.0);
    }

    r = length (z);

    n++;
  }

  return (length (z) - 2.0) * pow (Scale, -float (n));
}

// Calculates de distance from a position p to the scene
float DistanceEstimator (out vec3 p) {
  p.yz *= Rotate (0.2 * PI);
  p.yx *= Rotate (0.3 * PI);
  p.xz *= Rotate (0.29 * PI);
  float sierpinski = sierpinski3 (p);
  return sierpinski;
}

// Marches the ray in the scene
vec4 RayMarcher (vec3 ro, vec3 rd) {
  float steps = 0.0;
  float totalDistance = 0.0;
  float minDistToScene = 100.0;
  vec3 minDistToScenePos = ro;
  float minDistToOrigin = 100.0;
  vec3 minDistToOriginPos = ro;
  vec4 col = vec4 (0.0, 0.0, 0.0, 1.0);
  vec3 curPos = ro;
  bool hit = false;
  vec3 p = vec3 (0.0);

  for (steps = 0.0; steps < float (MaximumRaySteps); steps++) {
    p = ro + totalDistance * rd; // Current position of the ray
    float distance = DistanceEstimator (p); // Distance from the current position to the scene
    curPos = ro + rd * totalDistance;
    if (minDistToScene > distance) {
      minDistToScene = distance;
      minDistToScenePos = curPos;
    }
    if (minDistToOrigin > length (curPos)) {
      minDistToOrigin = length (curPos);
      minDistToOriginPos = curPos;
    }
    totalDistance += distance; // Increases the total distance armched
    if (distance < MinimumDistance) {
      hit = true;
      break; // If the ray marched more than the max steps or the max distance, breake out
    }
    else if (distance > MaximumDistance) {
      break;
    }
  }

  float iterations = float (steps) + log (log (MaximumDistance)) / log (2.0) - log (log (dot (curPos, curPos))) / log (2.0);

  if (minDistToScene > MinimumDistance) {

  }

  if (hit) {
    col.rgb = vec3 (0.8 + (length (curPos) / 8.0), 1.0, 0.8);
    col.rgb = hsv2rgb (col.rgb);

  }
  else {
    col.rgb = vec3 (0.8 + (length (minDistToScenePos) / 8.0), 1.0, 0.8);
    col.rgb = hsv2rgb (col.rgb);
    col.rgb *= 1.0 / pow (minDistToScene, 1.0);
    col.rgb /= 15.0 * map (sin (iTime * 3.0), -1.0, 1.0, 1.0, 3.0);
  }
  col.rgb /= iterations / 10.0; // Ambeint occlusion
  col.rgb /= pow (distance (ro, minDistToScenePos), 2.0);
  col.rgb *= 2000.0;

  return col;
}

void mainImage (out vec4 fragColor, in vec2 fragCoord) {
  // Normalized pixel coordinates (from 0 to 1)
  vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
  uv *= 0.2;
  uv.y -= 0.015;
  vec2 m = iMouse.xy / iResolution.xy;

  vec3 ro = vec3 (-40, 30.1, -10); // Ray origin
  //ro.yz *= Rotate (-m.y * 2.0 * PI + PI - 1.1); // Rotate thew ray with the mouse rotation
  //ro.xz *= Rotate (-iTime * 2.0 * PI / 10.0);
  vec3 rd = R (uv, ro, vec3 (0, 1, 0), 1.); // Ray direction (based on mouse rotation)

  vec4 col = RayMarcher (ro, rd);

  // Output to screen
  fragColor = vec4 (col);
}