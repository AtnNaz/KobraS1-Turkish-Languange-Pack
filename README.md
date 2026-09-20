# Kobra S1 Türkçe Arayüz

Kobra S1'in ekranını Türkçeye çevirir. Menülerden hata mesajlarına kadar arayüzdeki
523 metnin hepsi çevrildi.

Anycubic firmware'e yeni dil eklemeye izin vermiyor, o yüzden tek yol mevcut dillerden
birinin yerine geçmek. İtalyancayı seçtim. Kurduktan sonra yazıcıda
**Ayarlar > Dil > Türkçe** diyorsunuz, o kadar.

Firmware 2.7.2.7 ile yaptım ve orada test ettim. Rinkhals kurulu olması şart değil ama
varsa işiniz daha kolay, aşağıda anlatıyorum.

## Kurulum

[Releases](../../releases) sayfasından size uyanı indirin:

- Yazıcıda **Rinkhals varsa** → `app-turkish-ui-ks1.swu`
- **Rinkhals yoksa**, düz stok firmware → `turkish-ui-stock-ks1.swu`
- Stok kurulumdan **geri dönmek** isterseniz → `turkish-ui-stock-revert-ks1.swu`

Hepsinin kurulumu aynı. Dosyayı FAT32 biçimli bir USB belleğe atın, ama adını
`update.swu` yapın ve `aGVscF9zb3Nf` adında bir klasörün içine koyun. Yani şöyle olacak:

```
USB:/aGVscF9zb3Nf/update.swu
```

Belleği yazıcıya takın. Bip sesi gelir, biraz bekler, kendi kendine yeniden başlar.
Bir terslik olursa USB'de `aGVscF9zb3Nf/install-turkish-ui.log` diye bir günlük dosyası
oluşuyor, oraya bakın.

### Rinkhals varsa ne oluyor

Normal bir Rinkhals uygulaması olarak kuruluyor ve her açılışta çeviriyi tekrar
uyguluyor. Bunun sebebi şu: Anycubic firmware güncellemesi çeviri dosyasının üstüne
yazıp İtalyancayı geri getiriyor. Uygulama açılışta bunu fark edip Türkçeyi geri koyuyor,
siz uğraşmıyorsunuz.

SSH'ı açıksa USB'yle uğraşmadan da kurabilirsiniz:

```bash
sh tools/install_ssh.sh <yazıcının-ip-adresi>
```

### Rinkhals yoksa

Stok paket dosyaları doğrudan değiştiriyor, ikisinin de yedeğini alarak. Çeviri dosyasını
değiştiriyor, bir de `K3SysUi` içindeki `Italiano` yazısını `Türkçe` yapıyor.

Burada dikkat edilecek bir şey var. Sonradan Rinkhals kurmaya karar verirseniz **önce
geri alma paketini çalıştırın.** Rinkhals kendi yamasını uygulamadan önce `K3SysUi`
dosyasının MD5'ine bakıyor, değiştirilmiş dosyada bu kontrol tutmuyor ve Rinkhals menüsü
ekranda hiç görünmüyor. Bunu sonradan fark etmek can sıkıcı.

## Nasıl çalışıyor

Ekran arayüzü aslında bir Qt uygulaması ve çevirilerini
`/userdata/app/gk/Translate/` altındaki `.qm` dosyalarından okuyor. Yaptığım şey İtalyanca
dosyasının yerine tamamı Türkçe olan bir `.qm` koymak.

Menüde görünen dil isimleri ise çeviri dosyasında değil, `K3SysUi` programının içinde
sabit duruyor. Her dil için 12 baytlık bir yer ayrılmış. `Türkçe` UTF-8'de tam 8 bayt
tutuyor, `Italiano` da öyle, yani aynı yere sığıyor ve hiçbir adres kaymıyor. Şanslıyız.

Rinkhals kuruluyken diskteki program dosyasına dokunulmuyor. Rinkhals'ın kendi yöntemi
izleniyor: kopyasını al, kopyayı yamala, onu çalıştır, orijinali yerine koy.

Ekran fontunda ğ, ı, ş, İ gibi harfler zaten var, o tarafta sorun çıkmadı.

## Çeviriyi beğenmediyseniz

Hepsi tek dosyada: [`translations/tr.json`](translations/tr.json). İngilizcesinin
karşısındaki Türkçeyi değiştirip kaydedin.

İki şeye dikkat: `%1` gibi işaretler yazıcının oraya bir sayı koyacağı anlamına geliyor,
onları silmeyin. Bir metni boş bırakırsanız ekranda İngilizcesi görünür.

Sonra `python3 tools/build_qm.py` çalıştırın, çeviri dosyası yeniden üretilir.

Ekrana sığmayan bir şey görürseniz haber verin ya da kısaltıp gönderin, memnun olurum.

## Kendiniz derlemek isterseniz

Bu depoda Anycubic'in hiçbir dosyası yok, koymak istemedim. O yüzden derlerken stok
firmware'i kendiniz veriyorsunuz. Anycubic'ten ya da
[Rinkhals firmware arşivinden](https://rinkhals.firmwareforge.org) indirebilirsiniz.

```bash
python3 tools/extract_stock.py /indirdiginiz/stok_2.7.2.7.swu   # kaynak metinleri çıkarır
python3 tools/build_qm.py                                        # Türkçe .qm üretir
sh tools/build_swu.sh                                            # dist/ altına üç paket
```

Python 3 ve `zip`/`unzip` dışında bir şeye ihtiyaç yok. Qt kurmanıza gerek yok, `.qm`
dosyasını okuyup yazan kodu (`tools/qm.py`) sıfırdan yazdım; stok dosyaları bayt bayt
aynı şekilde geri üretebildiğini doğruladım.

## Bilinen sıkıntılar

İtalyanca kullanıyorsanız bu paket size göre değil, onun yerini alıyor.

Menü etiketi yamasını sadece 2.7.2.7 üzerinde doğruladım. Başka bir firmware sürümünde
çeviri yine yüklenir ama menüde `Italiano` yazmaya devam eder. Bir şey bozulmaz.

Çeviriler 2.7.2.7'deki metin listesinden çıkarıldı. Daha yeni bir firmware yeni metinler
eklediyse onlar İngilizce görünür.

Rinkhals'ta açılışta ekran bir kez yenileniyor, bu normal. Rahatsız ediyorsa kapatabilirsiniz:

```bash
set_app_property 20-turkish-ui patch_label False
```

O zaman menüde `Italiano` yazar ama içerik yine Türkçe olur.

## Son notlar

Anycubic'le de Rinkhals ekibiyle de bir ilgim yok, kendi yazıcım için yaptım. Yazıcınıza
bir şey olursa sorumluluk kabul etmiyorum, ama geri alma paketi bunun için var.

[Rinkhals](https://github.com/rinkhals-community/Rinkhals) olmasa bunların hiçbiri
olmazdı.Teşekkürler Rinkhals.

Kod MIT lisanslı, çeviriler de öyle. Detay için [NOTICE](NOTICE).

---

**English:** Turkish language pack for the Anycubic Kobra S1 touch screen. It takes over
the Italian language slot, so picking **Settings > Language > Türkçe** switches the whole
UI to Turkish. All 523 strings are translated. Works with or without
[Rinkhals](https://github.com/rinkhals-community/Rinkhals) — grab the matching `.swu` from
[Releases](../../releases), put it on a FAT32 USB stick as `aGVscF9zb3Nf/update.swu` and
plug it in.

No Anycubic files are redistributed here: the build pulls the source strings out of a
stock firmware you supply yourself, and the `K3SysUi` binary is patched in place behind an
MD5 check, the same way Rinkhals does it. Not affiliated with Anycubic or Rinkhals.
