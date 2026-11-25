# Aule App

<p>
  <a href="https://github.com/meet-aule/aule-hw"><img src="https://img.shields.io/badge/Hardware-aule--hw-1f6feb.svg" alt="Hardware de Aule"></a>
  <a href="https://github.com/meet-aule/aule-fw"><img src="https://img.shields.io/badge/Firmware-aule--fw-2da44e.svg" alt="Firmware de Aule"></a>
  <a href="https://github.com/meet-aule/aule-sw"><img src="https://img.shields.io/badge/Servidor-aule--sw-d97706.svg" alt="Servidor de Aule"></a>
  <a href="https://github.com/meet-aule/aule-app"><img src="https://img.shields.io/badge/App-Aule-8250df.svg" alt="App de Aule"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/Licencia-Apache%202.0-blue.svg" alt="Apache 2.0"></a>
</p>

([English](README.md) | Español)

**Aule es el tutor de IA de código abierto.** Este repositorio es la app para los adultos que rodean al niño: el padre o la madre que configura el aparato, y quien la familia invite a seguir su aprendizaje.

El aparato es para el niño. La app es para la familia. Nunca se convierte en una segunda pantalla para el niño.

## Qué hace

- **Configurar el aparato.** Conectar Aule al Wi-Fi por Bluetooth y vincularlo a la familia.
- **Seguir el avance.** Qué practicó el niño, qué ya domina y qué le toca, en lenguaje simple.
- **Entrar a una sesión.** Escuchar, o intervenir como tutor humano, en la misma sala de LiveKit que usa el aparato.
- **Controlar la privacidad.** Las autorizaciones, lo que Aule recuerda y el borrado de los datos del niño o de la cuenta entera, en un solo lugar. Los ajustes del micrófono y de las sesiones llegan después de la v0.

## Estado

v0, en desarrollo en la rama `feat/app-v0`. Escrita desde cero con Flutter para Android e iOS.

- **Funciona con la plataforma de hoy** (cuando tenga una ruta pública, brecha 1 más abajo): entrar con un código por correo, la autorización del padre o la madre antes de cualquier dato del niño, agregar y editar niños, el avance con resúmenes y habilidades, los avisos y todos los controles de privacidad (autorizaciones, lo que Aule recuerda, borrar los datos de un niño o la cuenta entera).
- **Detrás de banderas hasta que el servidor o el firmware estén listos:** los datos de cada sesión y las sesiones en curso, escuchar e intervenir, enlazar un aparato, el Wi-Fi por Bluetooth y entrar con Google (solo en Android).
- **Funciona de punta a punta en modo de demostración**, con todas las banderas prendidas menos Google, datos inventados y sin pedir Bluetooth, ubicación ni micrófono.
- **Todavía no se ha compilado.** No hay ningún binario, no se ha corrido el analizador ni ninguna prueba. Las carpetas `android/` e `ios/` son las plantillas de Flutter 3.47.7 con los permisos, las reglas de copias de seguridad y los textos de los permisos ya incluidos: ver [docs/platform.md](docs/platform.md) (en inglés).

## Probarla en modo de demostración

El modo de demostración no necesita servidor. La app habla con datos falsos en memoria y nada sale del celular; una franja delgada arriba lo recuerda.

```sh
flutter pub get                               # también escribe los textos traducidos
flutter run                                   # sin AULE_API_BASE: modo de demostración
flutter run --dart-define=AULE_DEMO=true      # lo mismo, de forma explícita
```

La familia de la demostración es inventada:

| Para probar | Usa |
|---|---|
| Entrar como la apoderada de la demostración, Ana | `ana@example.com`, código `123456` |
| Crear una familia nueva y vacía | cualquier otro correo, código `123456`, y luego un nombre |
| Ver el caso en que el código no se pudo enviar | `error@example.com` |
| Enlazar un aparato al instante | código `K7QM2X` |
| Enlazar un aparato que confirma a los pocos segundos | código `W8PZ3R` |
| Conectarse al Wi-Fi de la demostración | clave `aule1234` |

Ana tiene dos hijos, Mati y Lu, con resúmenes, habilidades, recuerdos, tres avisos (uno necesita atención) y, en el caso de Mati, una sesión en curso para escuchar. Su tiempo se renueva cuando se acaba; si la terminas, queda terminada hasta que la app vuelva a abrirse. Configurar el aparato encuentra un «Aule 3F2A» inventado sin tocar el Bluetooth, e intervenir no prende ningún micrófono real. Una familia nueva de la demostración empieza sin niños y sin aparatos.

Para usar la plataforma en tu propia computadora, pasa su dirección base (aquí, el emulador de Android; el simulador de iOS usa `http://127.0.0.1:8091/v1`):

```sh
flutter run --dart-define=AULE_API_BASE=http://10.0.2.2:8091/v1
```

Todos los `--dart-define` y la compilación de producción están en [docs/platform.md](docs/platform.md).

```sh
flutter test                # pruebas unitarias y de widgets
dart format lib test        # la única revisión que se corrió al escribir la v0
```

## Cómo está organizado el código

```
android/, ios/                los proyectos de cada plataforma (docs/platform.md)
lib/main.dart, lib/app.dart   arranque, proveedores, rutas, tema
lib/core/                     configuración, API (HTTP y datos falsos), sesión, almacenamiento,
                              rutas, colores y letras, textos (es y en), widgets compartidos
lib/features/auth/            entrar con un código por correo (Google detrás de una bandera)
lib/features/consent/         la autorización del padre o la madre, antes de cualquier dato del niño
lib/features/children/        agregar y editar niños
lib/features/progress/        resúmenes, habilidades, sesiones y avisos
lib/features/privacy/         autorizaciones, recuerdos, borrar datos y la cuenta
lib/features/device/          configurar el aparato: Wi-Fi por Bluetooth, enlace
lib/features/live/            entrar a una sesión en curso con LiveKit
```

Cada palabra que lee la familia sale de `lib/core/l10n/app_es.arb` y `app_en.arb`, en español del Perú y en inglés. Los textos que escribe el servidor (resúmenes, avisos, recuerdos) se muestran tal como llegan.

## Privacidad desde el diseño

- No se pregunta nada del niño antes de la autorización del padre o la madre, y las casillas empiezan sin marcar. La pantalla de autorización dice qué se guarda siempre (el perfil, los datos y el resumen de cada sesión, el avance y los avisos) y qué decide la familia (los recuerdos y las conversaciones por escrito); el audio y el video nunca se guardan. Cada respuesta, sí o no, se registra con la versión de las palabras que leyó la familia (`app-2026-11-v2`), y una prueba falla si esas palabras cambian sin una versión nueva.
- Si no se puede registrar la autorización de voz, el niño recién creado se borra. Si tampoco se puede borrar, la app dice que el perfil existe sin autorización y ofrece borrarlo o intentarlo otra vez. Si se pierde la respuesta al crear un perfil, la app lo busca antes de volver a intentarlo, así que nunca crea dos.
- Quitar el permiso de voz, o borrar a un niño o la cuenta, cierra la sesión que esté en curso cuando la app puede verla (`sessionList`); si no, avisa que esa sesión puede seguir hasta que termine (brechas 5 y 6b).
- El token del apoderado vive solo en el Llavero de iOS o en el almacén cifrado de Android. Nada del niño se guarda en el celular, y los campos del niño le piden al teclado que no aprenda sus palabras. El manifiesto apaga las copias de seguridad y las transferencias entre celulares, y las versiones de producción no permiten tráfico sin cifrar. El selector de apps no muestra ninguna captura de la app (iOS, y Android 13 en adelante).
- No hay ningún SDK de analítica, de reportes de fallas, de publicidad ni de Firebase. Las versiones de producción no registran nada, ni siquiera los errores no atrapados. En desarrollo, el registro propio de la app solo lleva nombres de eventos, rutas y estados, y LiveKit registra por su cuenta.
- Entrar a una sesión en curso está hecho para que un adulto nunca esté escondido. La app muestra el aviso antes de cada entrada, llegue como llegue a esa pantalla; entra con un token que solo permite escuchar y rechaza uno oculto, de datos, de cámara o que ya permita hablar; prende el micrófono solo después de que la plataforma lo autoriza; y sale de la sala cuando pasa a segundo plano. Avisarle al niño, en voz alta y en su pantalla, le toca al tutor y al aparato (brecha 4b), así que `liveJoin` queda apagada hasta que eso exista.
- Los avisos por correo traen el texto completo del aviso, y apagarlos también apaga los que necesitan atención; la app lo dice antes de apagarlos (brecha 10).

## Lo que le falta al servidor

La app ya está lista para estos cambios. Hasta que llegue cada uno, su bandera queda apagada fuera del modo de demostración.

| # | Falta | Qué hace la app mientras tanto |
|---|---|---|
| 1 | **No hay una API pública.** La plataforma solo escucha en su propia máquina, y la ruta de la web usa cookies. El cambio más pequeño es un paso directo, solo con token, bajo `playground.meetaule.com/session/api/v1`. | Modo de demostración, o una plataforma local. |
| 2 | **El token no se renueva.** Las sesiones duran 30 días fijos. | La familia vuelve a entrar con un código nuevo. |
| 3 | **No hay una lista de las sesiones de un niño** (`GET /v1/children/{id}/sessions`). | La lista se arma con los resúmenes y no se detectan sesiones en curso. Bandera `sessionList`. |
| 4a | **Los apoderados no pueden entrar a una sesión en curso**: faltan las rutas para entrar y cambiar de modo, y la sala admite dos. | Bandera `liveJoin`. |
| 4b | **Al niño no se le avisa.** El tutor tiene que decir, con palabras fijas y al instante, cuando un adulto entra, interviene, le devuelve la sesión, sale o la termina, y retomar cuando se desconecta un adulto que estaba hablando. La página de la sesión en la web, y la pantalla y la luz del aparato cuando se pueda entrar a sus sesiones, tienen que mostrar «tu familia está escuchando» mientras haya un adulto en la sala. La plataforma tiene que rechazar la entrada hasta que ambas cosas existan. | La bandera `liveJoin` queda apagada. La parte de la app está lista: el aviso, entrar solo a escuchar, el micrófono solo después de la autorización, y pedir el modo de escucha cuando el adulto devuelve la sesión o sale. |
| 5 | **Terminar una sesión no la detiene al instante.** | Bandera `liveJoin`. Después de quitar un permiso o de borrar datos, la app avisa que la sesión puede tardar unos minutos en terminar. |
| 6a | **La autorización no se crea junto con el niño.** | La app crea al niño, registra la autorización y borra al niño si no se pudo registrar la voz; si eso falla, dice que el perfil existe sin autorización y ofrece borrarlo. Si se pierde una respuesta, la busca en `me` antes de reintentar. Queda un caso: si la familia se va después de una respuesta perdida que `me` no pudo confirmar, el niño queda sin autorización, visible en Familia y Privacidad, donde se puede borrar. Recibir las autorizaciones al crear al niño lo resuelve. |
| 6b | **Quitar el permiso de voz, o borrar a un niño o la cuenta, no cierra una sesión en curso.** | Con `sessionList` prendida, la app lee las sesiones al momento, cierra las que están en curso y avisa si no pudo. Sin ella, la hoja avisa que la sesión en curso puede seguir. Propuesta: que la plataforma cierre las sesiones del niño y borre sus salas al quitar la voz y al borrar a un niño o a una familia. |
| 6c, 6d | No hay historial de autorizaciones; no se registra la aceptación de la política al crear la cuenta. | Fuera de la v0. Tampoco se vuelve a preguntar cuando cambia el texto de la autorización (un `kConsentPolicyVersion` nuevo); eso le toca a la app en la v1. |
| 7 | **No hay Sign in with Apple nativo.** | En iOS solo se entra con el código por correo. |
| 8 | **Los aparatos no llegan a la activación** a través del borde de OTA. | Bandera `deviceLink`. |
| 9 | Opcional: el estado de un enlace; paginar avisos, resúmenes y recuerdos; invitar a un segundo apoderado; exportar los datos y leer las conversaciones guardadas. | Fuera de la v0. La app muestra los 100 recuerdos más recientes y lo dice cuando puede haber más. |
| 10 | **Un solo interruptor para todos los avisos por correo.** Apagarlo también apaga los avisos que necesitan atención, y cada correo trae el texto completo del aviso. | La app lo dice en la ayuda y pregunta antes de apagar los correos. Propuesta: interruptores separados para los resúmenes y para los avisos que necesitan atención, estos prendidos por defecto; correos de atención que digan dónde mirar en lugar de lo que pasó; y qué hacer en casos urgentes. |

Antes de prender `bleWifi`, el firmware además tiene que activar BluFi para aule-v0.2, dejar de registrar la clave del Wi-Fi, revisar el tamaño del nombre de la red y de la clave, y anunciar un nombre propio por aparato. Cuando se pueda entrar a las sesiones del aparato, también tendrá que mostrar en la tinta electrónica y con su luz que un adulto está escuchando o hablando (brecha 4b).

**Antes de publicar la app:** los orígenes del borde deben usar HTTPS (Cloudflare Origin CA) o un túnel, para que el token nunca cruce internet sin cifrar entre el borde y el servidor.

## Cómo encajan las piezas

```
aule-hw   el aparato: placa, tinta electrónica, audio, carcasa
aule-fw   firmware: xiaozhi-esp32 + transporte LiveKit (WebRTC)
aule-sw   servidor central: tutor de voz, aparatos, API para familias
aule-app  la app para familias                                  (este repositorio)
```

## Licencia

Apache License 2.0. Ver [LICENSE](LICENSE). Las tipografías incluidas, Inter y Source Serif 4, usan la SIL Open Font License 1.1 (`assets/fonts/`).

---

Hecho en Lima, Perú, por [Aule](https://meetaule.com) · admin@meetaule.com
