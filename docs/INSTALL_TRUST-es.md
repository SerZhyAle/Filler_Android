# Por qué Android muestra advertencias sobre el APK de Filler - y qué tocar

<!-- languages -->
Idiomas: [English](INSTALL_TRUST.md) - [Русский](INSTALL_TRUST-ru.md) - [Українська](INSTALL_TRUST-uk.md) - [Deutsch](INSTALL_TRUST-de.md) - [Italiano](INSTALL_TRUST-it.md) - Español - [Français](INSTALL_TRUST-fr.md) - [Português](INSTALL_TRUST-pt.md) - [العربية](INSTALL_TRUST-ar.md) - [हिन्दी](INSTALL_TRUST-hi.md) - [বাংলা](INSTALL_TRUST-bn.md) - [اردو](INSTALL_TRUST-ur.md) - [简体中文](INSTALL_TRUST-zh.md)
<!-- /languages -->

Filler es una pequeña app gratuita de un desarrollador independiente. Cuando instalas el APK firmado desde GitHub Releases o SourceForge en lugar de Google Play, Android muestra algunos avisos durante la instalación. Aquí se explica cuáles son, por qué aparecen y exactamente qué tocar.

## 1. Qué es la advertencia

Puedes encontrarte con dos cosas. Las palabras entre comillas son las que muestra Android (textos en inglés; la traducción entre paréntesis es solo para entenderlos, no es el texto de la pantalla):

- **"For security, your phone currently isn't allowed to install unknown apps from this source."** (por seguridad, tu teléfono no tiene permiso por ahora para instalar apps desconocidas desde esta fuente). Android lo muestra la primera vez que abres un APK desde un navegador o un administrador de archivos al que no le has permitido instalar apps. Tiene un botón **Settings** (Ajustes). La pantalla que se abre con él se llama **Install unknown apps** (Instalar apps desconocidas), y el permiso es por app: tu navegador o tu administrador de archivos.
- **"Play Protect doesn't recognize this app's developer"** (Play Protect no reconoce al desarrollador de esta app) o **"App blocked to protect your device"** (app bloqueada para proteger tu dispositivo). Play Protect es el analizador integrado en los servicios de Google Play. Puede ofrecer **More details** (Más detalles) e **Install anyway** (Instalar de todos modos), o bien **OK** (Aceptar).

La redacción cambia un poco entre versiones de Android y fabricantes. Estos son los textos en inglés; en un teléfono configurado en otro idioma, Android muestra su propia traducción de ellos (esta página no cita esa traducción, porque no puede confirmarla para todas las versiones; las traducciones entre paréntesis son solo para entender los textos).

## 2. Por qué aparece

- **Apps desconocidas.** Android considera que toda app que no viene de una tienda instalada viene de una "fuente desconocida" y te pregunta una vez, para la app que abrió el archivo. El aviso se refiere a la fuente, no a Filler.
- **Play Protect.** El APK de GitHub Releases y SourceForge está firmado con la clave de publicación propia de Filler, y no es una instalación que Google Play haya contado, así que Play Protect no tiene historial del desarrollador. Un desarrollador independiente nuevo no es reconocido hasta que se acumulan instalaciones; la advertencia no significa que la app sea dañina, y no es una equivocación ni una falla. A medida que más personas la instalen, la advertencia puede desaparecer; no es una promesa.
- **Google Play.** La misma app en Google Play está firmada por Play App Signing y no muestra estos avisos. Si quieres evitarlos, instálala desde Google Play.

Antes de instalar, puedes comparar el archivo con el archivo `.sha256` publicado junto a él: deben contener el mismo valor SHA-256. Un valor distinto significa que la descarga está dañada o que no es de Filler; elimínala.

## 3. Qué tocar

1. Abre el APK descargado desde tu navegador o administrador de archivos.
2. En **"For security, your phone currently isn't allowed to install unknown apps from this source."** toca **Settings**, activa **Allow from this source** (Permitir desde esta fuente) solo para esa app (tu navegador o administrador de archivos) y regresa.
3. Toca **Install** (Instalar). En **"Play Protect doesn't recognize this app's developer"** toca **More details** y luego **Install anyway**. Filler no pide nada más.
4. Después vuelve a desactivar **Allow from this source**: en los ajustes de Android abre **Apps** (Aplicaciones), la app que usaste (navegador o administrador de archivos), **Install unknown apps**. Esto se aplica a cada app por separado y se puede revertir en cualquier momento.

No desactives Play Protect ni ninguna otra protección para instalar Filler: aquí nada lo requiere. La app para reloj se instala en el reloj de la misma manera, con la herramienta que uses para instalar APK en el reloj; los avisos son los mismos.

## 4. Lo que Filler nunca hace

Esta lista dice lo mismo que la [política de privacidad](https://serzhyale.github.io/Filler_Android/privacy-es.html) y las respuestas de Seguridad de los datos en Google Play.

- No tiene permiso de internet, así que no envía nada a nadie: ni al desarrollador, ni a un servidor, ni a otra app.
- No tiene código de analíticas, informes de fallos, publicidad ni rastreo, y no crea ninguna cuenta.
- No abre, lee, copia ni modifica tus propios archivos, y elimina solo los archivos temporales que él mismo escribió.
- No lee tus contactos, fotos, mensajes, ubicación ni los datos de otras apps.
- La app para teléfono pide cinco permisos y la app para reloj cuatro, solo para ejecutar un relleno a tiempo y mantenerlo en marcha con la pantalla apagada; ninguno de ellos da acceso a tus archivos ni a una red.

<!-- Rendered by tools/locale/render-translations.ps1 from INSTALL_TRUST.md and tools/locale/dictionaries/es.json. Never edit it by hand. -->
