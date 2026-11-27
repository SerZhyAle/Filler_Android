# Android के लिए Filler

<!-- languages -->
भाषाएँ: [English](README.md) - [Русский](README_ru.md) - [Українська](README_uk.md) - [Deutsch](README_de.md) - [Italiano](README_it.md) - [Español](README_es.md) - [Français](README_fr.md) - [Português](README_pt.md) - [العربية](README_ar.md) - हिन्दी - [বাংলা](README_bn.md) - [اردو](README_ur.md) - [简体中文](README_zh.md)
<!-- /languages -->

Filler स्टोरेज डिवाइस की खाली जगह को अस्थायी फ़ाइलों से भरता है और फिर उन्हें हटा देता है। आप आंतरिक स्टोरेज, मेमोरी कार्ड या उस पर कोई फ़ोल्डर चुनते हैं; Filler अपनी मापी हुई खाली जगह और वह हिस्सा दिखाता है जिसे वह सिस्टम के लिए खाली रखता है, आपकी पुष्टि की गई मात्रा तक लिखता है, और इस दौरान दिखाता रहता है कि कितना लिखा गया, कितना प्रतिशत पूरा हुआ और कितना समय बाकी है, और अपनी लिखी हर फ़ाइल हटा देता है - रन पूरा होने, रोकने, लिखने में त्रुटि, रीस्टार्ट या मेमोरी कार्ड निकाले जाने के बाद। आपकी अपनी फ़ाइलें जैसी हैं वैसी ही रहती हैं। फ़ोन पर भरना शेड्यूल पर भी चलता है: ऐप बंद होने पर भी तय समय पर, रीस्टार्ट के बाद भी, सामान्य 1 GB खाली रखते हुए, दिन में अधिकतम एक बार, और हर रन इतिहास में दर्ज होता है। एक ही एप्लिकेशन आईडी, `com.sza.filler`, में Android ऐप और Wear OS ऐप दोनों आते हैं।

यह FastMediaSorter का लोकल-स्टोरेज वाला Filler है, अपने अलग ऐप के रूप में, और एक स्वतंत्र प्रोडक्ट है: यह इस परिवार के दूसरे प्रोडक्ट के साथ कोई एप्लिकेशन कोड साझा नहीं करता, केवल प्रकाशित अनुबंध साझा करता है।

## बिल्ड करना

JDK और Android SDK इंस्टॉल होने पर, `./gradlew :phone:assembleDebug :wear:assembleDebug` फ़ोन ऐप और घड़ी के ऐप के डीबग APK बनाता है। यह प्रोडक्ट कहाँ से आया: [docs/PLAN_BOOTSTRAP_HANDOFF.md](docs/PLAN_BOOTSTRAP_HANDOFF.md)।

## निजता

डेवलपर को आपका कोई डेटा नहीं मिलता: न कोई खाता, न एनालिटिक्स, न विज्ञापन, न ट्रैकिंग। Filler के पास इंटरनेट एक्सेस नहीं है, इसलिए डिवाइस से कुछ भी बाहर नहीं जाता; फ़ोन ऐप केवल वही माँगता है जिससे शेड्यूल किया गया भरना ऐप बंद होने पर भी समय पर चले, और घड़ी का ऐप केवल वही जिससे उसकी स्क्रीन बंद रहने पर भी भरना चलता रहे। पूरी नीति: [निजता नीति](https://serzhyale.github.io/Filler_Android/privacy-hi.html)।

## GitHub Releases या SourceForge से APK इंस्टॉल करना

Google Play के बाहर प्रकाशित, साइन किए हुए फ़ोन और घड़ी के APK के कारण Android एक स्रोत से अज्ञात ऐप की अनुमति माँगता है और डेवलपर के बारे में Play Protect की सूचना भी दिखा सकता है। हर संदेश क्या है, क्यों दिखता है और ठीक-ठीक किस पर टैप करना है, यह [इंस्टॉल गाइड](docs/INSTALL_TRUST-hi.md) में है। Google Play पर यही ऐप Play App Signing से साइन होता है और उसमें इनमें से कोई संदेश नहीं आता।

## संपर्क

ईमेल [sza@ukr.net](mailto:sza@ukr.net), GitHub [SerZhyAle](https://github.com/SerZhyAle)। सवाल और बग रिपोर्ट [GitHub issues](https://github.com/SerZhyAle/Filler_Android/issues) के रूप में भेज सकते हैं।

यह प्रोजेक्ट AI की भरपूर मदद से विकसित किया जाता है; हर बदलाव की समीक्षा लेखक करता है।

## लाइसेंस

MIT - [LICENSE](LICENSE) देखें।

<!-- Rendered by tools/locale/render-translations.ps1 from README.md and tools/locale/dictionaries/hi.json. Never edit it by hand. -->
