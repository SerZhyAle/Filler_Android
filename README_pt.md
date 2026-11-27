# Filler para Android

<!-- languages -->
Idiomas: [English](README.md) - [Русский](README_ru.md) - [Українська](README_uk.md) - [Deutsch](README_de.md) - [Italiano](README_it.md) - [Español](README_es.md) - [Français](README_fr.md) - Português - [العربية](README_ar.md) - [हिन्दी](README_hi.md) - [বাংলা](README_bn.md) - [اردو](README_ur.md) - [简体中文](README_zh.md)
<!-- /languages -->

O Filler preenche o espaço livre de um dispositivo de armazenamento com arquivos temporários e depois os exclui. Você escolhe o armazenamento interno ou um cartão de memória, ou uma pasta nele; o Filler mostra o espaço livre que mediu e a parte que mantém livre para o sistema, grava até a quantidade que você confirmar, mostrando quanto já foi gravado, a porcentagem e o tempo restante, e exclui todos os arquivos que gravou - após uma execução concluída, uma interrupção, um erro de gravação, uma reinicialização ou a remoção de um cartão de memória. Seus próprios arquivos ficam como estão. No telefone, o preenchimento também pode ser agendado: em um horário definido com o app fechado, mesmo depois de reiniciar, mantendo livre o 1 GB habitual, no máximo uma vez por dia, com cada execução listada em um histórico. Um único identificador de aplicativo, `com.sza.filler`, abrange o app para Android e o app para Wear OS.

É o Filler de armazenamento local do FastMediaSorter como um app próprio e um produto independente: não compartilha código de aplicativo com os outros produtos da família, apenas os contratos publicados.

## Compilação

Com o JDK e o Android SDK instalados, `./gradlew :phone:assembleDebug :wear:assembleDebug` compila os APKs de depuração do app do telefone e do app do relógio. De onde veio o produto: [docs/PLAN_BOOTSTRAP_HANDOFF.md](docs/PLAN_BOOTSTRAP_HANDOFF.md).

## Privacidade

O desenvolvedor não recebe nenhum dado seu: sem conta, sem análise de uso, sem publicidade, sem rastreamento. O Filler não tem acesso à internet, portanto nada sai do dispositivo; o app do telefone pede somente o que permite executar um preenchimento agendado na hora com o app fechado, e o app do relógio somente o que mantém um preenchimento em andamento enquanto a tela dele está apagada. A política completa: [política de privacidade](https://serzhyale.github.io/Filler_Android/privacy-pt.html).

## Como instalar o APK do GitHub Releases ou do SourceForge

Os APKs assinados do telefone e do relógio publicados fora do Google Play fazem o Android pedir para permitir apps desconhecidos de uma fonte e podem mostrar um aviso do Play Protect sobre o desenvolvedor. O que é cada aviso, por que aparece e onde exatamente tocar está no [guia de instalação](docs/INSTALL_TRUST-pt.md). O mesmo app no Google Play é assinado pelo Play App Signing e não passa por nenhum desses avisos.

## Contato

E-mail [sza@ukr.net](mailto:sza@ukr.net), GitHub [SerZhyAle](https://github.com/SerZhyAle). Perguntas e relatos de erros são bem-vindos como [issues no GitHub](https://github.com/SerZhyAle/Filler_Android/issues).

Este projeto é desenvolvido com forte auxílio de IA; o autor revisa cada alteração.

## Licença

MIT - consulte [LICENSE](LICENSE).

<!-- Rendered by tools/locale/render-translations.ps1 from README.md and tools/locale/dictionaries/pt.json. Never edit it by hand. -->
