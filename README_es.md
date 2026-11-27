# Filler para Android

<!-- languages -->
Idiomas: [English](README.md) - [Русский](README_ru.md) - [Українська](README_uk.md) - [Deutsch](README_de.md) - [Italiano](README_it.md) - Español - [Français](README_fr.md) - [Português](README_pt.md) - [العربية](README_ar.md) - [हिन्दी](README_hi.md) - [বাংলা](README_bn.md) - [اردو](README_ur.md) - [简体中文](README_zh.md)
<!-- /languages -->

Filler llena el espacio libre de un dispositivo de almacenamiento con archivos temporales y luego los vuelve a eliminar. Eliges el almacenamiento interno o una tarjeta de memoria, o una carpeta en ella; Filler muestra el espacio libre que midió y la parte que deja libre para el sistema, escribe hasta la cantidad que confirmas, con lo escrito, el porcentaje y el tiempo restante a la vista, y elimina todos los archivos que escribió - después de una ejecución terminada, una detención, un error de escritura, un reinicio o el retiro de una tarjeta de memoria. Tus propios archivos se quedan como están. En el teléfono, un relleno también se ejecuta según una programación: a una hora fijada con la app cerrada, incluso después de un reinicio, dejando libre el 1 GB habitual, como máximo una vez al día, con cada ejecución anotada en un historial. Un solo identificador de aplicación, `com.sza.filler`, abarca la app para Android y la app para Wear OS.

Es el Filler de almacenamiento local de FastMediaSorter convertido en una app propia, y un producto independiente: no comparte código de aplicación con los demás productos de la familia, solo los contratos publicados.

## Compilación

Con el JDK y el Android SDK instalados, `./gradlew :phone:assembleDebug :wear:assembleDebug` compila los APK de depuración de la app para teléfono y de la app para reloj. De dónde viene el producto: [docs/PLAN_BOOTSTRAP_HANDOFF.md](docs/PLAN_BOOTSTRAP_HANDOFF.md).

## Privacidad

El desarrollador no recibe ninguno de tus datos: sin cuenta, sin analíticas, sin publicidad, sin rastreo. Filler no tiene acceso a internet, así que nada sale del dispositivo; la app para teléfono pide solo lo que permite ejecutar un relleno programado a tiempo con la app cerrada, y la app para reloj solo lo que mantiene un relleno en marcha mientras su pantalla está apagada. La política completa: [política de privacidad](https://serzhyale.github.io/Filler_Android/privacy-es.html).

## Instalación del APK desde GitHub Releases o SourceForge

Los APK firmados para teléfono y reloj que se publican fuera de Google Play hacen que Android pida permitir apps desconocidas desde una fuente, y pueden mostrar un aviso de Play Protect sobre el desarrollador. En la [guía de instalación](docs/INSTALL_TRUST-es.md) se explica qué es cada aviso, por qué aparece y exactamente qué tocar. La misma app en Google Play está firmada por Play App Signing y no muestra ninguno de estos avisos.

## Contacto

Correo electrónico [sza@ukr.net](mailto:sza@ukr.net), GitHub [SerZhyAle](https://github.com/SerZhyAle). Las preguntas y los informes de errores son bienvenidos como [issues de GitHub](https://github.com/SerZhyAle/Filler_Android/issues).

Este proyecto se desarrolla con mucha ayuda de IA; el autor revisa cada cambio.

## Licencia

MIT - consulta [LICENSE](LICENSE).

<!-- Rendered by tools/locale/render-translations.ps1 from README.md and tools/locale/dictionaries/es.json. Never edit it by hand. -->
