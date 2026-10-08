# IPA غير موقّعة عبر GitHub Actions

الملفات المطلوبة جاهزة في `.github/workflows/ios-unsigned.yml` و`scripts/build-unsigned-ios.sh`، مع محرك iOS محلي في `modules/long-image/ios`.

## تشغيل البناء

1. أنشئ مستودع GitHub فارغًا، وامنح الاتصال صلاحية رفع الملفات، ومنها ملفات workflows، وصلاحية تشغيل Actions.
2. ارفع المصدر إلى فرع `main`؛ سيبدأ البناء تلقائيًا. يمكن تشغيله أيضًا من **Actions → Build unsigned iPhone IPA → Run workflow**.
3. ينتج البناء artifact باسم `manhwa-studio-unsigned-ipa`، يحتوي على IPA وSHA-256. فك ضغط artifact ثم وقّع IPA بأداتك الخاصة.

لا يحتاج Action إلى شهادة Apple أو provisioning profile أو مفتاح حساب Apple. يستخدم macOS/Xcode للبناء على `iphoneos` وليس المحاكي، ويعطّل التوقيع ويتحقق من وجود ARM64، ويزيل التواقيع الموجودة في المكتبات المضمّنة قبل تغليف `Payload/*.app`.

## التحقق وحدود هذه النسخة

- Linux: نجح اختبار **كود C المستخدم في iOS نفسه** لمسار PNG → ملف RGBA على القرص → دمج طبقة شفافة → PNG. صورة 2000×100000؛ قورنت كل البكسلات وCRC مع حد ذاكرة للعملية يبلغ 64 MiB.
- نجحت فحوص TypeScript وESLint وExpo Doctor وحزمة JavaScript/Hermes الخاصة بـiOS.
- نجح توليد مشروع iOS وربط الوحدة محليًا بواسطة Expo autolinking.
- **لم يُجر تجميع Swift/Xcode أو اختبار على iPhone داخل بيئة Linux.** يضيف Action فحص صياغة Swift ثم بناء Xcode؛ نجاح الـIPA يجب تأكيده من نتيجة تشغيل Action.

محرك iOS يفك PNG ذات 8 بت تدريجيًا إلى ملف بكسلات على القرص، ويعرضها باستخدام CATiledLayer. يحتاج ملف البكسلات إلى `العرض × الارتفاع × 4` بايت من مساحة الهاتف. PNG ذات 16 بت تُرفض بوضوح. الصيغ الأخرى تستخدم ImageIO بحد 8 مليون بكسل؛ الصور الأطول تتطلب PNG حاليًا، ولا تُصغّر تلقائيًا. الحد التجريبي لـPNG هو عرض 32768 وارتفاع مليون بكسل، ضمن المساحة والوقت المتاحين.

التصدير يبقي قيم RGBA الأصلية كما هي حيث لا توجد تعديلات؛ تُرسم التعديلات في شريحة شفافة ثم تُركّب على البكسلات الأصلية. نسخ بيانات ICC/gamma موجود، لكن معالجة ملفات الألوان غير المعتادة وتطابق معاينة UIKit مع التصدير يحتاجان إلى اختبارات على جهاز. حفظ ملفات RGBA طويلة على القرص، والتنظيف التلقائي وإعادة الاستكمال أثناء التصدير، يحتاجان إلى تحسينات لاحقة.

## البناء محليًا على Mac

```sh
npm ci
npx expo prebuild --platform ios --no-install
(cd ios && pod install --repo-update)
bash scripts/build-unsigned-ios.sh
```

الناتج: `build/manhwa-studio-unsigned.ipa`. يحتاج التطبيق إلى iOS 16.4 أو أحدث.

## المكوّن الخارجي

يتضمن المحرك libpng 1.6.55 من مشروع pnggroup/libpng، ضمن `Vendor/libpng` مع ملف LICENSE الأصلي. لا تُنقل مفاتيح GitHub أو Apple إلى المصدر أو ملف workflow.
