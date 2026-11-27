# Por que o Android avisa sobre o APK do Filler - e onde tocar

<!-- languages -->
Idiomas: [English](INSTALL_TRUST.md) - [Русский](INSTALL_TRUST-ru.md) - [Українська](INSTALL_TRUST-uk.md) - [Deutsch](INSTALL_TRUST-de.md) - [Italiano](INSTALL_TRUST-it.md) - [Español](INSTALL_TRUST-es.md) - [Français](INSTALL_TRUST-fr.md) - Português - [العربية](INSTALL_TRUST-ar.md) - [हिन्दी](INSTALL_TRUST-hi.md) - [বাংলা](INSTALL_TRUST-bn.md) - [اردو](INSTALL_TRUST-ur.md) - [简体中文](INSTALL_TRUST-zh.md)
<!-- /languages -->

O Filler é um pequeno app gratuito de um desenvolvedor independente. Quando você instala o APK assinado do GitHub Releases ou do SourceForge em vez do Google Play, o Android mostra alguns avisos no caminho. Veja quais são, por que aparecem e onde exatamente tocar.

## 1. O que é o aviso

Você pode encontrar duas coisas. As palavras entre aspas são as que o Android mostra (textos em inglês; a tradução entre parênteses serve apenas para compreensão):

- **"For security, your phone currently isn't allowed to install unknown apps from this source."** (por segurança, no momento o seu telefone não tem permissão para instalar apps desconhecidos desta fonte). O Android mostra isso na primeira vez que você abre um APK de um navegador ou de um gerenciador de arquivos ao qual você não permitiu instalar apps. Há um botão **Settings** (Configurações). A tela que ele abre se chama **Install unknown apps** (Instalar apps desconhecidos), e a permissão é por app: seu navegador ou seu gerenciador de arquivos.
- **"Play Protect doesn't recognize this app's developer"** (o Play Protect não reconhece o desenvolvedor deste app) (ou **"App blocked to protect your device"**, app bloqueado para proteger o dispositivo). O Play Protect é o verificador integrado ao Google Play Services. Ele pode oferecer **More details** (Mais detalhes) e **Install anyway** (Instalar mesmo assim), ou **OK**.

A redação varia um pouco entre versões do Android e fabricantes. Os trechos entre aspas são os textos em inglês; em um telefone configurado em outro idioma, o Android mostra a própria tradução deles (esta página não reproduz o texto dessa tradução do Android, porque não pode confirmá-lo para todas as versões).

## 2. Por que ele aparece

- **Apps desconhecidos.** O Android considera que todo app que não vem de uma loja instalada vem de uma "fonte desconhecida" e pergunta uma vez, para o app que abriu o arquivo. A pergunta é sobre a fonte, não sobre o Filler.
- **Play Protect.** O APK no GitHub Releases e no SourceForge é assinado com a chave de lançamento do próprio Filler e não é uma instalação contabilizada pelo Google Play, portanto o Play Protect não tem histórico do desenvolvedor. Um desenvolvedor independente novo não é reconhecido até que as instalações se acumulem; o aviso não significa que o app seja nocivo e não é um engano nem um defeito. À medida que mais pessoas instalam, ele pode desaparecer; isso não é uma promessa.
- **Google Play.** O mesmo app no Google Play é assinado pelo Play App Signing e não passa por esses avisos. Se quiser evitá-los, instale-o pelo Google Play.

Antes de instalar, você pode comparar o arquivo com o arquivo `.sha256` publicado ao lado dele: ambos devem ter o mesmo valor SHA-256. Um valor diferente significa que o download está danificado ou não é do Filler; exclua-o.

## 3. Onde tocar

1. Abra o APK baixado no seu navegador ou gerenciador de arquivos.
2. Em **"For security, your phone currently isn't allowed to install unknown apps from this source."** toque em **Settings**, ative **Allow from this source** (Permitir desta fonte) somente para esse app (seu navegador ou gerenciador de arquivos) e volte.
3. Toque em **Install** (Instalar). Em **"Play Protect doesn't recognize this app's developer"** toque em **More details** e depois em **Install anyway**. O Filler não pede mais nada.
4. Depois, desative **Allow from this source** novamente: nas configurações do Android, abra **Apps** (Aplicativos), o app que você usou (navegador ou gerenciador de arquivos), **Install unknown apps**. Isso vale por app e pode ser revertido a qualquer momento.

Não desative o Play Protect nem qualquer outra proteção para instalar o Filler: nada aqui precisa disso. O app do relógio é instalado no relógio da mesma forma, pela ferramenta que você usar para instalar APKs no relógio; os avisos são os mesmos.

## 4. O que o Filler nunca faz

Esta lista diz o mesmo que a [política de privacidade](https://serzhyale.github.io/Filler_Android/privacy-pt.html) e as respostas de Data safety do Google Play.

- Ele não tem permissão de internet, portanto não envia nada a ninguém: nem ao desenvolvedor, nem a um servidor, nem a outro app.
- Ele não tem código de análise de uso, de relatório de falhas, de publicidade ou de rastreamento e não cria nenhuma conta.
- Ele não abre, lê, copia nem altera seus próprios arquivos e exclui somente os arquivos temporários que ele mesmo gravou.
- Ele não lê seus contatos, fotos, mensagens, localização nem os dados de outros apps.
- O app do telefone pede cinco permissões e o app do relógio, quatro, apenas para executar um preenchimento na hora e mantê-lo em andamento com a tela apagada; nenhuma delas dá acesso aos seus arquivos ou a uma rede.

<!-- Rendered by tools/locale/render-translations.ps1 from INSTALL_TRUST.md and tools/locale/dictionaries/pt.json. Never edit it by hand. -->
