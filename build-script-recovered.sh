#!/usr/bin/env bash
set -euo pipefail

mkdir -p app/src/main/java/com/turkhunmete/namazvakti
mkdir -p app/src/main/assets
mkdir -p app/src/main/res/drawable
mkdir -p app/src/main/res/values

cp "$HTML_FILE" app/src/main/assets/index.html

python3 <<'PY'
from pathlib import Path

p = Path("app/src/main/assets/index.html")
html = p.read_text(encoding="utf-8")

native_script = r'''
<script>
(function () {
  if (window.__nativeStatusAndAlarmSyncV37) return;
  window.__nativeStatusAndAlarmSyncV37 = true;

  var ALARM_STORE = "namaz.v29.alarm.settings";
  var DEFAULT_ALARMS = {
    enabled: { sabah: true, ogle: true, ikindi: true, aksam: true, yatsi: true },
    preMinutes: 10,
    mode: "vibrate",
    style: "detailed"
  };

  function txt(id) {
    var el = document.getElementById(id);
    return el ? String(el.textContent || "").trim() : "";
  }

  function fixText(v) {
    v = String(v || "");
    v = v.replace(/Ö�le/g, "Öğle").replace(/ö�le/g, "öğle");
    v = v.replace(/G�neş/g, "Güneş").replace(/g�neş/g, "güneş");
    v = v.replace(/Yats�/g, "Yatsı").replace(/yats�/g, "yatsı");
    v = v.replace(/S�radaki/g, "Sıradaki").replace(/s�radaki/g, "sıradaki");
    v = v.replace(/Kald�/g, "Kaldı").replace(/kald�/g, "kaldı");
    v = v.replace(/s�re/g, "süre").replace(/S�re/g, "Süre");
    v = v.replace(/g�n/g, "gün").replace(/G�n/g, "Gün");
    return v.trim();
  }

  function valid(v) {
    v = fixText(v);
    return v && v !== "—" && v !== "-" && v !== "--:--";
  }

  function shortActive(v) {
    v = fixText(v);
    if (v.indexOf("→") >= 0) return fixText(v.split("→")[0]);
    return v;
  }

  function todayIsoLocal() {
    var d = new Date();
    var y = d.getFullYear();
    var m = String(d.getMonth() + 1).padStart(2, "0");
    var day = String(d.getDate()).padStart(2, "0");
    return y + "-" + m + "-" + day;
  }

  function addDaysIso(iso, days) {
    var parts = iso.split("-").map(Number);
    var d = new Date(parts[0], parts[1] - 1, parts[2]);
    d.setDate(d.getDate() + days);
    var y = d.getFullYear();
    var m = String(d.getMonth() + 1).padStart(2, "0");
    var day = String(d.getDate()).padStart(2, "0");
    return y + "-" + m + "-" + day;
  }

  function getRecordByDate(iso) {
    try {
      if (window.PRAYER_DATA && Array.isArray(window.PRAYER_DATA)) {
        for (var i = 0; i < window.PRAYER_DATA.length; i++) {
          if (window.PRAYER_DATA[i] && window.PRAYER_DATA[i].date === iso) return window.PRAYER_DATA[i];
        }
      }
    } catch (e) {}
    try {
      if (typeof currentRecord === "function" && iso === todayIsoLocal()) return currentRecord();
    } catch (e) {}
    return null;
  }

  function getTodayRecord() {
    return getRecordByDate(todayIsoLocal());
  }

  function loadAlarmSettings() {
    try {
      var raw = localStorage.getItem(ALARM_STORE);
      if (!raw) return JSON.parse(JSON.stringify(DEFAULT_ALARMS));
      var data = JSON.parse(raw);
      var merged = JSON.parse(JSON.stringify(DEFAULT_ALARMS));
      merged.enabled = Object.assign(merged.enabled, data.enabled || {});
      if (typeof data.preMinutes !== "undefined") merged.preMinutes = Number(data.preMinutes);
      if (data.mode) merged.mode = String(data.mode);
      if (data.style) merged.style = String(data.style);
      if (![0,5,10,15,30].includes(merged.preMinutes)) merged.preMinutes = 10;
      if (!["silent","vibrate","sound"].includes(merged.mode)) merged.mode = "vibrate";
      if (!["simple","detailed","manevi"].includes(merged.style)) merged.style = "detailed";
      return merged;
    } catch (e) {
      return JSON.parse(JSON.stringify(DEFAULT_ALARMS));
    }
  }

  function saveAlarmSettings(s) {
    try { localStorage.setItem(ALARM_STORE, JSON.stringify(s)); } catch (e) {}
  }

  function cleanLegacyReminderUi() {
    try {
      var old = document.getElementById("reminderSettings");
      if (old) {
        old.style.display = "none";
        old.innerHTML = "";
      }
    } catch (e) {}
    try {
      if (typeof FARZ !== "undefined" && typeof state !== "undefined" && state.reminders) {
        FARZ.forEach(function(pair){
          var k = pair[0];
          if (state.reminders[k]) state.reminders[k].on = false;
        });
        if (typeof timers !== "undefined" && Array.isArray(timers)) {
          timers.forEach(clearTimeout);
          timers = [];
        }
        if (typeof save === "function") save();
      }
    } catch (e) {}
  }

  function makeAlarmUi() {
    try {
      cleanLegacyReminderUi();
      var tab = document.getElementById("tab-settings");
      if (!tab || document.getElementById("nativeAlarmSettingsV30")) return;
      var card = document.createElement("section");
      card.className = "settings-card";
      card.id = "nativeAlarmSettingsV30";
      card.innerHTML = '\n' +
        '<h3 style="margin:0 0 12px">Alarm Bildirimleri</h3><small>Her vakit için aç/kapat. Süre ve tür aşağıdaki ortak ayarlardan yönetilir.</small>' +
        '<label class="switch-row"><span><b>Sabah</b><small>Alarm açık/kapalı</small></span><input data-alarm-key="sabah" type="checkbox"></label>' +
        '<label class="switch-row"><span><b>Öğle</b><small>Alarm açık/kapalı</small></span><input data-alarm-key="ogle" type="checkbox"></label>' +
        '<label class="switch-row"><span><b>İkindi</b><small>Alarm açık/kapalı</small></span><input data-alarm-key="ikindi" type="checkbox"></label>' +
        '<label class="switch-row"><span><b>Akşam</b><small>Alarm açık/kapalı</small></span><input data-alarm-key="aksam" type="checkbox"></label>' +
        '<label class="switch-row"><span><b>Yatsı</b><small>Alarm açık/kapalı</small></span><input data-alarm-key="yatsi" type="checkbox"></label>' +
        '<div class="row"><div><b>Ön hatırlatma</b><small>Vakit girmeden önce uyarı</small></div><select id="alarmPreV30" class="offset-input"><option value="0">Kapalı</option><option value="5">5 dk önce</option><option value="10">10 dk önce</option><option value="15">15 dk önce</option><option value="30">30 dk önce</option></select></div>' +
        '<div class="row"><div><b>Bildirim türü</b><small>Alarm kanalını belirler</small></div><select id="alarmModeV30" class="offset-input"><option value="silent">Sessiz</option><option value="vibrate">Titreşimli</option><option value="sound">Sesli + titreşimli</option></select></div>' +
        '<div class="row"><div><b>Bildirim metni</b><small>Alarm üslubu</small></div><select id="alarmStyleV30" class="offset-input"><option value="simple">Basit</option><option value="detailed">Detaylı</option><option value="manevi">Manevi</option></select></div>' +
        '<div class="row"><div><b>Alarm test bildirimi</b><small>Seçili tür ve metinle hemen test eder</small></div><button id="testAlarmV30" class="primary ghost">Test et</button></div>' +
        '<pre id="alarmStatusV30" class="status">Alarm ayarları hazır.</pre>';
      var reminder = document.getElementById("reminderSettings");
      if (reminder && reminder.parentNode === tab) tab.insertBefore(card, reminder);
      else tab.appendChild(card);
      bindAlarmUi();
    } catch (e) {}
  }

  function bindAlarmUi() {
    var s = loadAlarmSettings();
    var keys = ["sabah","ogle","ikindi","aksam","yatsi"];
    keys.forEach(function(k){
      var cb = document.querySelector('[data-alarm-key="'+k+'"]');
      if (cb) cb.checked = !!s.enabled[k];
    });
    var pre = document.getElementById("alarmPreV30");
    var mode = document.getElementById("alarmModeV30");
    var style = document.getElementById("alarmStyleV30");
    if (pre) pre.value = String(s.preMinutes);
    if (mode) mode.value = s.mode;
    if (style) style.value = s.style;

    function changed() {
      var ns = loadAlarmSettings();
      keys.forEach(function(k){
        var cb = document.querySelector('[data-alarm-key="'+k+'"]');
        if (cb) ns.enabled[k] = !!cb.checked;
      });
      if (pre) ns.preMinutes = Number(pre.value || 0);
      if (mode) ns.mode = String(mode.value || "vibrate");
      if (style) ns.style = String(style.value || "detailed");
      saveAlarmSettings(ns);
      pushNativeAlarms(true);
      var st = document.getElementById("alarmStatusV30");
      if (st) st.textContent = "Ayarlar kaydedildi. Alarmlar yeniden kuruldu.";
    }

    keys.forEach(function(k){
      var cb = document.querySelector('[data-alarm-key="'+k+'"]');
      if (cb) cb.onchange = changed;
    });
    if (pre) pre.onchange = changed;
    if (mode) mode.onchange = changed;
    if (style) style.onchange = changed;

    var test = document.getElementById("testAlarmV30");
    if (test) test.onclick = function(){
      var ns = loadAlarmSettings();
      var payload = JSON.stringify({city:"Kayseri", label:"Öğle", time:"12:37", type:"time", mode:ns.mode, style:ns.style, preMinutes:ns.preMinutes});
      try {
        if (window.AndroidNotify && typeof window.AndroidNotify.requestPermission === "function") window.AndroidNotify.requestPermission();
        if (window.AndroidNotify && typeof window.AndroidNotify.testAlarm === "function") window.AndroidNotify.testAlarm(payload);
        else if (window.AndroidNotify && typeof window.AndroidNotify.show === "function") window.AndroidNotify.show("Öğle vakti", JSON.stringify({body:"Kayseri • Öğle vakti girdi. Saat: 12:37"}));
        var st = document.getElementById("alarmStatusV30");
        if (st) st.textContent = "Test bildirimi gönderildi.";
      } catch (e) {
        var st2 = document.getElementById("alarmStatusV30");
        if (st2) st2.textContent = "Test hatası: " + e.message;
      }
    };
  }

  function makeTimesLines(rec) {
    if (!rec) return [];
    var sabah = fixText(rec.sabah || "");
    var sabahSonu = fixText(rec.sabah_sonu || "");
    var ogle = fixText(rec.ogle || "");
    var ikindi = fixText(rec.ikindi || "");
    var aksam = fixText(rec.aksam || "");
    var yatsi = fixText(rec.yatsi || "");
    var yatsiSonu = fixText(rec.yatsi_sonu || "");
    var lines = [];
    if (valid(sabah) || valid(sabahSonu)) lines.push("Sabah " + sabah + (valid(sabahSonu) ? " • Sabah sonu " + sabahSonu : ""));
    if (valid(ogle) || valid(ikindi)) lines.push("Öğle " + ogle + (valid(ikindi) ? " • İkindi " + ikindi : ""));
    if (valid(aksam) || valid(yatsi)) lines.push("Akşam " + aksam + (valid(yatsi) ? " • Yatsı " + yatsi : ""));
    if (valid(yatsiSonu)) lines.push("Yatsı sonu " + yatsiSonu);
    return lines;
  }

  function pushNativeStatus(force) {
    try {
      if (typeof window.AndroidNotify === "undefined") return;
      var rec = getTodayRecord();
      var nextName = fixText(txt("nextName"));
      var nextTime = fixText(txt("nextTime"));
      var countdown = fixText(txt("countdown"));
      var active = shortActive(txt("arcTitle"));
      if (!valid(nextName) || !valid(countdown)) return;
      var title = "Sıradaki: " + nextName + " • " + countdown + " kaldı";
      var lines = [];
      if (valid(active)) lines.push("Şimdi: " + active);
      lines.push("Sıradaki: " + nextName + (valid(nextTime) ? " — " + nextTime : ""));
      lines.push("Kalan: " + countdown);
      var timesLines = makeTimesLines(rec);
      if (timesLines.length) { lines.push(""); for (var i = 0; i < timesLines.length; i++) lines.push(timesLines[i]); }
      var body = lines.join("\n");
      var key = title + "|" + body;
      if (!force && window.__lastNativeStatusKeyV30 === key) return;
      window.__lastNativeStatusKeyV30 = key;
      window.AndroidNotify.show(title, JSON.stringify({ body: body, tag: "active-prayer-summary", silent: true, status: true, requireInteraction: true }));
    } catch (e) {}
  }

  function buildAlarmPayload() {
    var settings = loadAlarmSettings();
    var today = todayIsoLocal();
    var tomorrow = addDaysIso(today, 1);
    var records = [getRecordByDate(today), getRecordByDate(tomorrow)];
    var labels = [["sabah", "Sabah"], ["ogle", "Öğle"], ["ikindi", "İkindi"], ["aksam", "Akşam"], ["yatsi", "Yatsı"]];
    var prayers = [];
    for (var r = 0; r < records.length; r++) {
      var rec = records[r];
      if (!rec || !rec.date) continue;
      for (var i = 0; i < labels.length; i++) {
        var key = labels[i][0];
        var label = labels[i][1];
        if (!settings.enabled[key]) continue;
        if (valid(rec[key])) prayers.push({ date: rec.date, key: key, label: label, time: fixText(rec[key]) });
      }
    }
    return { city: "Kayseri", preMinutes: settings.preMinutes, mode: settings.mode, style: settings.style, prayers: prayers };
  }

  function pushNativeAlarms(force) {
    try {
      if (typeof window.AndroidNotify === "undefined") return;
      if (typeof window.AndroidNotify.scheduleAlarms !== "function") return;
      var payload = buildAlarmPayload();
      var raw = JSON.stringify(payload);
      if (!force && window.__lastNativeAlarmPayloadV29 === raw) return;
      window.__lastNativeAlarmPayloadV29 = raw;
      window.AndroidNotify.scheduleAlarms(raw);
    } catch (e) {}
  }

  window.__pushNativeStatusV30 = pushNativeStatus;
  window.__pushNativeAlarmsV30 = pushNativeAlarms;

  makeAlarmUi();
  setTimeout(function(){ makeAlarmUi(); pushNativeStatus(true); pushNativeAlarms(true); }, 1800);
  setTimeout(function(){ makeAlarmUi(); pushNativeStatus(true); pushNativeAlarms(true); }, 5000);
  setInterval(function(){ pushNativeStatus(false); }, 60000);
  setInterval(function(){ pushNativeAlarms(false); }, 21600000);

  document.addEventListener("visibilitychange", function () {
    if (!document.hidden) setTimeout(function(){ makeAlarmUi(); pushNativeStatus(true); pushNativeAlarms(true); }, 800);
  });
})();
</script>
'''


if "__nativeStatusAndAlarmSyncV37" not in html:
  if "</body>" in html:
    html = html.replace("</body>", native_script + "\n</body>", 1)
  else:
    html += "\n" + native_script
# V34: Metinler buton düzeltmesi.
# Silme artık native confirm kullanmaz; ilk basışta onay ister, ikinci basışta siler. Yukarı/aşağı sadece birden fazla blok varsa aktif olur.
texts_css = r'''
<style>
.texts-v33-card{border:1px solid var(--line);background:linear-gradient(180deg,var(--panel2),var(--panel));border-radius:26px;padding:16px;margin:12px 0;box-shadow:0 18px 60px rgba(0,0,0,.35)}
.texts-v33-toolbar{display:flex;gap:8px;align-items:center;justify-content:space-between;margin:12px 0;flex-wrap:wrap}
.texts-v33-toolbar small{display:block;color:var(--muted);margin-top:4px;line-height:1.35}.texts-v33-filters{display:flex;gap:8px;flex-wrap:wrap}
.texts-v33-filter{border:1px solid var(--line);background:#080809;color:var(--muted);border-radius:999px;padding:9px 12px;font-weight:850}.texts-v33-filter.active{background:rgba(228,200,97,.14);border-color:rgba(228,200,97,.38);color:var(--accent)}
.texts-v33-empty{border:1px dashed rgba(228,200,97,.24);border-radius:24px;padding:24px;text-align:center;color:var(--muted);background:rgba(228,200,97,.035);line-height:1.45}.texts-v33-empty b{display:block;color:var(--accent);font-size:18px;margin-bottom:6px}
.text-block-v33{position:relative;border:1px solid var(--line);background:linear-gradient(180deg,#09090b,#050506);border-radius:24px;padding:15px;margin:10px 0;overflow:hidden;cursor:pointer;transition:transform .16s ease,border-color .16s ease,background .16s ease}.text-block-v33:active{transform:scale(.992)}.text-block-v33.starred{border-color:rgba(228,200,97,.45);background:linear-gradient(180deg,rgba(228,200,97,.075),#050506)}
.text-block-v33:before{content:"";position:absolute;inset:-60px -70px auto auto;width:140px;height:140px;border-radius:50%;background:radial-gradient(circle,rgba(228,200,97,.10),transparent 60%);pointer-events:none}.text-block-head-v33{position:relative;display:flex;align-items:flex-start;justify-content:space-between;gap:10px}.text-block-title-v33 b{display:block;font-size:20px;letter-spacing:-.025em}.text-block-title-v33 small{display:block;color:var(--muted);margin-top:4px;line-height:1.35}.text-preview-v33{position:relative;margin:12px 0 0;color:#d7d7db;white-space:pre-wrap;line-height:1.55;max-height:4.7em;overflow:hidden}.text-preview-v33:after{content:"";position:absolute;left:0;right:0;bottom:0;height:2.2em;background:linear-gradient(transparent,#050506)}.text-preview-v33:empty{display:none}.text-read-hint-v33{position:relative;margin-top:10px;color:var(--muted);font-size:12px;font-weight:800;letter-spacing:.04em}
.text-actions-v33{position:relative;display:flex;gap:7px;flex-wrap:wrap;margin-top:12px}.text-actions-v33 button,.star-btn-v33{border:1px solid var(--line);background:#080809;color:var(--muted);border-radius:14px;padding:9px 10px;font-weight:850}.text-actions-v33 button:disabled{opacity:.35}.text-actions-v33 button.danger{background:rgba(200,55,55,.16);border-color:rgba(255,90,90,.35);color:#ffb3b3}.star-btn-v33{min-width:44px;color:var(--accent);font-size:18px;padding:8px 10px}.star-btn-v33.on{background:rgba(228,200,97,.14);border-color:rgba(228,200,97,.42);color:var(--accent2)}
.text-modal-v33[hidden]{display:none}.text-modal-v33{position:fixed;inset:0;z-index:70;background:rgba(0,0,0,.78);backdrop-filter:blur(12px);display:grid;align-items:end}.text-modal-panel-v33{max-width:720px;width:100%;max-height:92vh;margin:0 auto;background:#030304;border:1px solid var(--line);border-bottom:0;border-radius:28px 28px 0 0;padding:18px 16px calc(24px + env(safe-area-inset-bottom));overflow:auto;box-shadow:0 -20px 80px rgba(0,0,0,.65)}.text-modal-head-v33{display:flex;align-items:flex-start;justify-content:space-between;gap:12px;margin-bottom:12px}.text-modal-head-v33 h2{margin:0;font-size:26px;letter-spacing:-.04em;line-height:1.1}.text-modal-head-v33 small{color:var(--accent);font-weight:900;letter-spacing:.18em;font-size:11px}.close-v33{width:44px;height:44px;border-radius:14px;border:1px solid var(--line);background:#09090a;color:var(--text);font-size:28px;line-height:1}.text-help-v33{font-size:12px;color:var(--muted);line-height:1.45}
.text-form-v33{display:grid;gap:10px}.text-form-v33 input,.text-form-v33 textarea,.text-form-v33 select{width:100%;background:var(--panel2);color:var(--text);border:1px solid var(--line);border-radius:16px;padding:13px;font:inherit}.text-form-v33 textarea{min-height:180px;resize:vertical;line-height:1.55}.text-form-grid-v33{display:grid;grid-template-columns:1fr 1fr;gap:10px}.text-form-actions-v33{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:4px}
.text-read-meta-v33{display:inline-flex;gap:8px;align-items:center;flex-wrap:wrap;color:var(--muted);font-weight:850;margin-bottom:12px}.text-read-meta-v33 span{border:1px solid var(--line);background:#080809;border-radius:999px;padding:7px 10px}.text-read-body-v33{white-space:pre-wrap;line-height:1.75;font-size:18px;color:#eeeeef;background:linear-gradient(180deg,#09090b,#050506);border:1px solid var(--line);border-radius:22px;padding:16px;min-height:120px}.text-read-actions-v33{display:grid;grid-template-columns:1fr 1fr 1fr;gap:9px;margin-top:12px}.text-read-actions-v33 button{border:1px solid var(--line);background:#080809;color:var(--text);border-radius:16px;padding:12px;font-weight:900}.text-read-actions-v33 button.primaryish{background:rgba(228,200,97,.16);border-color:rgba(228,200,97,.42);color:var(--accent2)}
@media(max-width:430px){.text-form-grid-v33,.text-form-actions-v33,.text-read-actions-v33{grid-template-columns:1fr}.text-block-title-v33 b{font-size:18px}.texts-v33-toolbar{display:grid}.texts-v33-filters{width:100%}.text-read-body-v33{font-size:17px}}
</style>
'''

texts_section = r'''
      <section class="tab" id="tab-texts">
        <div class="section-head"><h2>Metinler</h2><button id="newTextV33" class="pill">+ Yeni</button></div>
        <section class="texts-v33-card">
<div class="texts-v33-toolbar">
  <div><b>Kişisel metin blokları</b><small>Ayet, sure, dua veya notlarını bloklar halinde sakla. Karta dokunarak oku; düzenleme ayrı butondadır.</small></div>
  <div class="texts-v33-filters">
    <button class="texts-v33-filter active" data-text-filter="all">Tümü</button>
    <button class="texts-v33-filter" data-text-filter="star">Yıldızlı</button>
  </div>
</div>
<div id="textsListV33"></div>
        </section>
      </section>
'''

texts_nav = r'''
      <button class="nav-btn" data-tab="texts"><span class="nav-mark">☆</span><span>Metin</span></button>
'''

texts_edit_modal = r'''
<section class="text-modal-v33" id="textModalV33" hidden>
  <div class="text-modal-panel-v33">
    <div class="text-modal-head-v33">
      <div><small>METİN BLOĞU</small><h2 id="textModalTitleV33">Yeni metin</h2></div>
      <button class="close-v33" id="closeTextV33">×</button>
    </div>
    <div class="text-form-v33">
      <input id="textTitleV33" placeholder="Başlık">
      <div class="text-form-grid-v33">
        <select id="textTypeV33"><option value="ayet">Ayet</option><option value="sure">Sure</option><option value="dua">Dua</option><option value="not">Not</option></select>
        <input id="textRefV33" placeholder="Alt bilgi: Bakara 255, Yasin, vb.">
      </div>
      <textarea id="textBodyV33" placeholder="Metni buraya yaz..."></textarea>
      <label class="switch-row" style="padding:8px 0"><span><b>Yıldızlı</b><small>Favoriler filtresinde görünsün</small></span><input id="textStarV33" type="checkbox"></label>
      <small class="text-help-v33">Kartlara dokununca okuma ekranı açılır. Sıralama için karttaki yukarı/aşağı düğmelerini kullan.</small>
      <div class="text-form-actions-v33"><button id="saveTextV33" class="primary">Kaydet</button><button id="cancelTextV33" class="primary ghost">Vazgeç</button></div>
    </div>
  </div>
</section>
'''

texts_read_modal = r'''
<section class="text-modal-v33" id="textReadModalV33" hidden>
  <div class="text-modal-panel-v33">
    <div class="text-modal-head-v33">
      <div><small id="textReadKickerV33">METİN</small><h2 id="textReadTitleV33">Metin</h2></div>
      <button class="close-v33" id="closeReadV33">×</button>
    </div>
    <div class="text-read-meta-v33" id="textReadMetaV33"></div>
    <div class="text-read-body-v33" id="textReadBodyV33"></div>
    <div class="text-read-actions-v33">
      <button id="readStarV33" class="primaryish">☆ Yıldızla</button>
      <button id="readEditV33">Düzenle</button>
      <button id="readCloseV33">Kapat</button>
    </div>
  </div>
</section>
'''

texts_js = r'''
<script>
(function(){
  if(window.__metinlerV33) return; window.__metinlerV33 = true;
  var STORE='namaz.metinler.blocks';
  var OLD='namaz.metinler.v31.blocks';
  var filter='all'; var editingId=null; var readingId=null; var pendingDeleteId=null;
  function $(id){return document.getElementById(id)}
  function uid(){return 'm'+Date.now().toString(36)+Math.random().toString(36).slice(2,7)}
  function esc(s){return String(s||'').replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}
  function migrate(){try{if(!localStorage.getItem(STORE)&&localStorage.getItem(OLD))localStorage.setItem(STORE,localStorage.getItem(OLD))}catch(e){}}
  function load(){migrate();try{var a=JSON.parse(localStorage.getItem(STORE)||'[]');return Array.isArray(a)?a:[]}catch(e){return []}}
  function save(a){try{localStorage.setItem(STORE,JSON.stringify(a))}catch(e){}}
  function typeLabel(t){return ({ayet:'Ayet',sure:'Sure',dua:'Dua',not:'Not'}[t]||'Metin')}
  function get(id){return load().find(function(x){return x.id===id})}
  function preview(s){s=String(s||'').trim(); if(s.length<=260) return s; return s.slice(0,255).trim()+'…'}
  function openEdit(item){editingId=item&&item.id||null; $('textModalTitleV33').textContent=editingId?'Metni düzenle':'Yeni metin'; $('textTitleV33').value=item&&item.title||''; $('textTypeV33').value=item&&item.type||'ayet'; $('textRefV33').value=item&&item.ref||''; $('textBodyV33').value=item&&item.body||''; $('textStarV33').checked=!!(item&&item.star); $('textModalV33').hidden=false; setTimeout(function(){$('textTitleV33').focus()},80)}
  function closeEdit(){if($('textModalV33')) $('textModalV33').hidden=true; editingId=null}
  function openRead(item){if(!item)return; readingId=item.id; $('textReadTitleV33').textContent=item.title||'Başlıksız metin'; $('textReadKickerV33').textContent=typeLabel(item.type).toUpperCase(); $('textReadMetaV33').innerHTML='<span>'+esc(typeLabel(item.type))+'</span>'+(item.ref?'<span>'+esc(item.ref)+'</span>':''); $('textReadBodyV33').textContent=item.body||'—'; $('readStarV33').textContent=(item.star?'★ Yıldızlı':'☆ Yıldızla'); $('readStarV33').classList.toggle('primaryish',!!item.star); $('textReadModalV33').hidden=false}
  function closeRead(){if($('textReadModalV33')) $('textReadModalV33').hidden=true; readingId=null}
  function bind(){
    var n=$('newTextV33'); if(n&&!n.__b){n.__b=1;n.onclick=function(){openEdit(null)}}
    var c=$('closeTextV33'); if(c&&!c.__b){c.__b=1;c.onclick=closeEdit}
    var ca=$('cancelTextV33'); if(ca&&!ca.__b){ca.__b=1;ca.onclick=closeEdit}
    var cr=$('closeReadV33'); if(cr&&!cr.__b){cr.__b=1;cr.onclick=closeRead}
    var rc=$('readCloseV33'); if(rc&&!rc.__b){rc.__b=1;rc.onclick=closeRead}
    var re=$('readEditV33'); if(re&&!re.__b){re.__b=1;re.onclick=function(){var it=get(readingId); closeRead(); if(it) openEdit(it)}}
    var rs=$('readStarV33'); if(rs&&!rs.__b){rs.__b=1;rs.onclick=function(){if(readingId){toggleStar(readingId); var it=get(readingId); if(it) openRead(it)}}}
    var s=$('saveTextV33'); if(s&&!s.__b){s.__b=1;s.onclick=function(){var title=$('textTitleV33').value.trim()||'Başlıksız metin';var item={id:editingId||uid(),title:title,type:$('textTypeV33').value,ref:$('textRefV33').value.trim(),body:$('textBodyV33').value.trim(),star:$('textStarV33').checked};var a=load(); if(editingId){a=a.map(function(x){return x.id===editingId?item:x})}else{a.push(item)} save(a); closeEdit(); render();}}
    document.querySelectorAll('[data-text-filter]').forEach(function(b){if(!b.__b){b.__b=1;b.onclick=function(){filter=b.dataset.textFilter||'all';document.querySelectorAll('[data-text-filter]').forEach(function(x){x.classList.toggle('active',x.dataset.textFilter===filter)});render();}}})
  }
  function move(id,dir){var a=load(),i=a.findIndex(function(x){return x.id===id}); if(i<0) return; var j=i+dir; if(j<0||j>=a.length) return; var tmp=a[i];a[i]=a[j];a[j]=tmp;save(a);render()}
  function toggleStar(id){var a=load();a.forEach(function(x){if(x.id===id)x.star=!x.star});save(a);render()}
  function del(id){
    if(pendingDeleteId!==id){
      pendingDeleteId=id;
      render();
      setTimeout(function(){if(pendingDeleteId===id){pendingDeleteId=null;render()}},3500);
      return;
    }
    pendingDeleteId=null;
    save(load().filter(function(x){return x.id!==id}));
    render();
    if(readingId===id) closeRead();
  }
  function render(){var list=$('textsListV33'); if(!list) return; var a=load(); var arr=filter==='star'?a.filter(function(x){return x.star}):a; if(!arr.length){list.innerHTML='<div class="texts-v33-empty"><b>Henüz metin yok</b>+ Yeni ile ayet, sure, dua veya not ekleyebilirsin.</div>';return} list.innerHTML=arr.map(function(x){var i=a.findIndex(function(y){return y.id===x.id});return '<article class="text-block-v33 '+(x.star?'starred':'')+'" data-open="'+esc(x.id)+'"><div class="text-block-head-v33"><div class="text-block-title-v33"><b>'+esc(x.title)+'</b><small>'+esc(typeLabel(x.type))+(x.ref?' • '+esc(x.ref):'')+'</small></div><button class="star-btn-v33 '+(x.star?'on':'')+'" data-star="'+esc(x.id)+'">'+(x.star?'★':'☆')+'</button></div><div class="text-preview-v33">'+esc(preview(x.body))+'</div><div class="text-read-hint-v33">OKUMAK İÇİN KARTA DOKUN</div><div class="text-actions-v33"><button data-edit="'+esc(x.id)+'">Düzenle</button><button data-up="'+esc(x.id)+'" '+(i===0?'disabled':'')+'>Yukarı</button><button data-down="'+esc(x.id)+'" '+(i===a.length-1?'disabled':'')+'>Aşağı</button><button data-del="'+esc(x.id)+'" class="'+(pendingDeleteId===x.id?'danger':'')+'">'+(pendingDeleteId===x.id?'Onayla sil':'Sil')+'</button></div></article>'}).join('');
    list.querySelectorAll('[data-open]').forEach(function(card){card.onclick=function(e){if(e.target.closest('button'))return; var it=get(card.dataset.open); if(it) openRead(it)}});list.querySelectorAll('[data-star]').forEach(function(b){b.onclick=function(e){e.stopPropagation();toggleStar(b.dataset.star)}});list.querySelectorAll('[data-edit]').forEach(function(b){b.onclick=function(e){e.stopPropagation();var it=get(b.dataset.edit); if(it) openEdit(it)}});list.querySelectorAll('[data-up]').forEach(function(b){b.onclick=function(e){e.stopPropagation();move(b.dataset.up,-1)}});list.querySelectorAll('[data-down]').forEach(function(b){b.onclick=function(e){e.stopPropagation();move(b.dataset.down,1)}});list.querySelectorAll('[data-del]').forEach(function(b){b.onclick=function(e){e.stopPropagation();del(b.dataset.del)}});
  }
  function boot(){bind();render();document.querySelectorAll('.nav-btn').forEach(function(b){if(!b.__metinlerRefresh){b.__metinlerRefresh=1;b.addEventListener('click',function(){if(b.dataset.tab==='texts')setTimeout(render,60)})}})}
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',boot); else boot();
  setTimeout(boot,500); setTimeout(boot,2000); document.addEventListener('visibilitychange',function(){if(!document.hidden)setTimeout(boot,100)});
})();
</script>
'''

if "__metinlerV33" not in html:
    if "</head>" in html:
        html = html.replace("</head>", texts_css + "\n</head>", 1)
    else:
        html = texts_css + "\n" + html

    if 'id="tab-texts"' not in html:
        marker = '<section class="tab" id="tab-settings">'
        if marker in html:
            html = html.replace(marker, texts_section + "\n" + marker, 1)
        else:
            html = html.replace('</main>', texts_section + '\n</main>', 1) if '</main>' in html else html + texts_section

    if 'data-tab="texts"' not in html:
        settings_nav = '<button class="nav-btn" data-tab="settings"><span class="nav-mark">⋯</span><span>Ayar</span></button>'
        if settings_nav in html:
            html = html.replace(settings_nav, texts_nav + "\n" + settings_nav, 1)
        else:
            html = html.replace('</nav>', texts_nav + '\n</nav>', 1) if '</nav>' in html else html

    if 'id="textModalV33"' not in html:
        if "</body>" in html:
            html = html.replace("</body>", texts_edit_modal + "\n" + texts_read_modal + "\n" + texts_js + "\n</body>", 1)
        else:
            html += "\n" + texts_edit_modal + "\n" + texts_read_modal + "\n" + texts_js



# V36: Foldable / large-screen safe responsive layout.
foldable_css = r"""
<style>
@media (min-width: 720px){
  .app{max-width:1180px;padding:28px 24px 104px;background:radial-gradient(circle at 92% -10%,rgba(228,200,97,.12),transparent 30%),#000}
  .topbar{max-width:1120px;margin:0 auto 2px}.topbar h1{font-size:38px}.clock span{font-size:38px}
  .tab.active{animation:none}
  #tab-home.active{display:grid;grid-template-columns:minmax(0,1.04fr) minmax(320px,.96fr);gap:14px 16px;align-items:start;max-width:1120px;margin:0 auto}
  #tab-home>.hero-card,#tab-home>.day-progress-card,#tab-home>.segment-card,#tab-home>.current-card{grid-column:1}
  #tab-home>.times,#tab-home>.home-tracker,#tab-home>.arc-card,#tab-home>.phase-card{grid-column:2}
  #tab-calendar.active,#tab-tracker.active,#tab-texts.active,#tab-settings.active{max-width:880px;margin:0 auto}
  .settings-card,.stats-card,.texts-v33-card{border-radius:28px}
  .tracker-list{grid-template-columns:repeat(5,minmax(92px,1fr))}
  .bottom-nav{left:50%;right:auto;transform:translateX(-50%);width:min(720px,calc(100% - 28px));border:1px solid var(--line);border-bottom:0;border-radius:28px 28px 0 0;box-shadow:0 -18px 80px rgba(0,0,0,.55)}
  .nav-btn{width:138px}
  .text-modal-v33{align-items:center}.text-modal-panel-v33{border-radius:30px;border:1px solid var(--line);max-height:min(88vh,760px);margin:24px auto;padding:22px}
}
@media (min-width: 920px){
  #tab-tracker.active .stats-grid{grid-template-columns:repeat(4,1fr)}
  #tab-tracker.active .stats-card:first-of-type{display:grid;grid-template-columns:220px 1fr;gap:18px;align-items:center}
  #tab-tracker.active .progress-ring{margin:0}
  #tab-settings.active{display:grid;grid-template-columns:1fr 1fr;gap:14px;align-items:start;max-width:1050px}
  #tab-settings.active .section-head{grid-column:1/-1}
}
@media (min-width: 980px) and (orientation: landscape){
  #tab-texts.active{max-width:1080px}.texts-v33-card{padding:18px}.texts-v33-toolbar{align-items:center}
  #textsListV33{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}
  #textsListV33 .texts-v33-empty{grid-column:1/-1}
  .text-block-v33{margin:0}
}
@media (min-width: 1200px){
  .app{max-width:1280px}#tab-home.active{grid-template-columns:1fr 1fr;max-width:1200px}.hero-row h2{font-size:52px}.countdown strong{font-size:42px}
}
@media (max-width: 719px){body.foldable-wide .app{max-width:680px}}
</style>
"""
foldable_js = r"""
<script>
(function(){
  if(window.__foldableV36) return; window.__foldableV36 = true;
  function applyFoldableClass(){
    try{
      var w = Math.max(window.innerWidth||0, document.documentElement.clientWidth||0);
      var h = Math.max(window.innerHeight||0, document.documentElement.clientHeight||0);
      document.body.classList.toggle('foldable-wide', w >= 720);
      document.body.classList.toggle('foldable-landscape', w >= 820 && w > h);
      document.body.classList.toggle('foldable-book', w >= 720 && h >= 720 && Math.abs(w-h) < 260);
    }catch(e){}
  }
  window.addEventListener('resize', function(){setTimeout(applyFoldableClass,80)});
  window.addEventListener('orientationchange', function(){setTimeout(applyFoldableClass,180)});
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded', applyFoldableClass); else applyFoldableClass();
  setTimeout(applyFoldableClass,600);
})();
</script>
"""
if "__foldableV36" not in html:
    if "</head>" in html:
        html = html.replace("</head>", foldable_css + "\n</head>", 1)
    else:
        html = foldable_css + "\n" + html
    if "</body>" in html:
        html = html.replace("</body>", foldable_js + "\n</body>", 1)
    else:
        html += "\n" + foldable_js



safety_script = r'''
<script>
(function(){
  if (window.__v37FileInputSafety) return;
  window.__v37FileInputSafety = true;

  function byId(id){ return document.getElementById(id); }
  function clickFile(id){ var f=byId(id); if(f){ try{ f.click(); }catch(e){} } }
  function setMsg(msg){
    var n = byId('notifyStatus') || byId('calendarInfo');
    if(n) n.textContent = msg;
  }

  function bindFileButtons(){
    var calBtn = byId('calendarImportBtn');
    if(calBtn && !calBtn.__v37Bound){
      calBtn.__v37Bound = true;
      calBtn.addEventListener('click', function(e){ e.preventDefault(); clickFile('calendarImport'); });
    }
    var importBtn = byId('importBtn');
    if(importBtn && !importBtn.__v37Bound){
      importBtn.__v37Bound = true;
      importBtn.addEventListener('click', function(e){ e.preventDefault(); clickFile('importData'); });
    }
    var calInput = byId('calendarImport');
    if(calInput && !calInput.__v37Bound){
      calInput.__v37Bound = true;
      calInput.addEventListener('change', function(e){
        var file = e.target.files && e.target.files[0];
        if(!file){ setMsg('Dosya seçilmedi.'); return; }
        if(typeof importCalendarFile === 'function') importCalendarFile(file);
        e.target.value = '';
      });
    }
    var dataInput = byId('importData');
    if(dataInput && !dataInput.__v37Bound){
      dataInput.__v37Bound = true;
      dataInput.addEventListener('change', function(e){
        var file = e.target.files && e.target.files[0];
        if(!file){ setMsg('Dosya seçilmedi.'); return; }
        if(typeof importBackup === 'function') importBackup(file);
        e.target.value = '';
      });
    }
  }

  window.addEventListener('error', function(ev){
    try{ console.log('V37 UI error:', ev.message); }catch(e){}
  });

  setTimeout(bindFileButtons, 500);
  setTimeout(bindFileButtons, 1800);
  document.addEventListener('visibilitychange', function(){ if(!document.hidden) setTimeout(bindFileButtons, 300); });
})();
</script>
'''
if "__v37FileInputSafety" not in html:
  if "</body>" in html:
    html = html.replace("</body>", safety_script + "\n</body>", 1)
  else:
    html += "\n" + safety_script

export_import_fix_script = r"""
<script>
(function(){
  if(window.__v38ImportExportFix) return;
  window.__v38ImportExportFix = true;

  function byId(id){ return document.getElementById(id); }
  function msg(t){
    try{
      var el = byId('notifyStatus') || byId('calendarInfo') || byId('alarmStatusV30');
      if(el) el.textContent = t;
    }catch(e){}
  }

  function allLocalStorage(){
    var out = {};
    try{
      for(var i=0;i<localStorage.length;i++){
        var k = localStorage.key(i);
        out[k] = localStorage.getItem(k);
      }
    }catch(e){}
    return out;
  }

  function backupPayload(){
    var payload = {
      app: 'Kayseri Namaz',
      backupVersion: 38,
      exportedAt: new Date().toISOString(),
      note: 'Namaz Vakti tam yedek',
      state: (typeof state !== 'undefined') ? state : null,
      tracker: (typeof tracker !== 'undefined') ? tracker : null,
      calendar: (typeof DATA !== 'undefined') ? DATA : null,
      localStorage: allLocalStorage()
    };
    return payload;
  }

  function doExportBackup(){
    try{
      var payload = backupPayload();
      var json = JSON.stringify(payload, null, 2);
      var name = 'namaz-vakti-yedek-' + new Date().toISOString().slice(0,10) + '.json';

      if(window.AndroidNotify && typeof window.AndroidNotify.saveFile === 'function'){
        window.AndroidNotify.saveFile(name, json);
        msg('Dışa aktarma hazırlanıyor. Açılan ekranda kaydet.');
        return;
      }

      var blob = new Blob([json], {type:'application/json;charset=utf-8'});
      var a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = name;
      document.body.appendChild(a);
      a.click();
      setTimeout(function(){ URL.revokeObjectURL(a.href); a.remove(); }, 1500);
      msg('Yedek dışa aktarıldı.');
    }catch(e){
      msg('Dışa aktarma hatası: ' + (e && e.message ? e.message : e));
    }
  }

  function restoreFromBackupObject(data){
    if(!data || typeof data !== 'object') throw new Error('Geçersiz yedek dosyası.');

    if(data.localStorage && typeof data.localStorage === 'object'){
      Object.keys(data.localStorage).forEach(function(k){
        try{ localStorage.setItem(k, String(data.localStorage[k] || '')); }catch(e){}
      });
    }

    try{
      if(data.calendar && Array.isArray(data.calendar)){
        if(typeof DATA !== 'undefined') DATA = data.calendar;
        if(typeof CUSTOM_DATA !== 'undefined') localStorage.setItem(CUSTOM_DATA, JSON.stringify(data.calendar));
      }
      if(data.tracker && typeof data.tracker === 'object' && typeof tracker !== 'undefined'){
        tracker = data.tracker;
      }
      if(data.state && typeof data.state === 'object' && typeof state !== 'undefined'){
        if(typeof defaults !== 'undefined') state = Object.assign({}, defaults, data.state);
        else state = data.state;
        if(state) state.activeNotify = false;
      }
      if(typeof save === 'function') save();
    }catch(e){}

    msg('Yedek içe aktarıldı. Uygulama yenileniyor...');
    setTimeout(function(){ location.reload(); }, 700);
  }

  function doImportBackup(file){
    if(!file){ msg('Dosya seçilmedi.'); return; }
    var reader = new FileReader();
    reader.onload = function(){
      try{
        var data = JSON.parse(String(reader.result || ''));
        restoreFromBackupObject(data);
      }catch(e){
        msg('Yedek içe aktarılamadı: ' + (e && e.message ? e.message : e));
      }
    };
    reader.onerror = function(){ msg('Dosya okunamadı.'); };
    reader.readAsText(file, 'utf-8');
  }

  function doImportCalendar(file){
    if(!file){ msg('Dosya seçilmedi.'); return; }
    var name = String(file.name || '').toLowerCase();

    if(name.endsWith('.xlsx') || name.endsWith('.xls')){
      msg('Excel dosyası bu sürümde doğrudan okunmaz. JSON/CSV kullan. Bu dosyayı senin için JSON’a çevirdim.');
      return;
    }

    if(typeof importCalendarFile === 'function'){
      try{ importCalendarFile(file); }
      catch(e){ msg('Takvim yükleme hatası: ' + (e && e.message ? e.message : e)); }
      return;
    }

    msg('Takvim yükleme işlevi bulunamadı.');
  }

  window.exportBackup = doExportBackup;
  window.importBackup = doImportBackup;
  window.__v38ImportCalendar = doImportCalendar;

  function bindV38(){
    var exportBtn = byId('exportData');
    if(exportBtn){
      exportBtn.onclick = function(e){ if(e) e.preventDefault(); doExportBackup(); };
    }

    var importBtn = byId('importBtn');
    var importInput = byId('importData');
    if(importBtn && importInput){
      importBtn.onclick = function(e){ if(e) e.preventDefault(); try{ importInput.click(); }catch(err){} };
      importInput.onchange = function(e){
        var f = e.target.files && e.target.files[0];
        doImportBackup(f);
        e.target.value = '';
      };
    }

    var calBtn = byId('calendarImportBtn');
    var calInput = byId('calendarImport');
    if(calInput){
      try{ calInput.setAttribute('accept', '.json,.csv,text/csv,application/json,text/plain'); }catch(e){}
    }
    if(calBtn && calInput){
      calBtn.onclick = function(e){ if(e) e.preventDefault(); try{ calInput.click(); }catch(err){} };
      calInput.onchange = function(e){
        var f = e.target.files && e.target.files[0];
        doImportCalendar(f);
        e.target.value = '';
      };
    }
  }

  setTimeout(bindV38, 300);
  setTimeout(bindV38, 1200);
  setTimeout(bindV38, 3000);
  document.addEventListener('visibilitychange', function(){ if(!document.hidden) setTimeout(bindV38, 300); });
})();
</script>
"""
if "__v38ImportExportFix" not in html:
    if "</body>" in html:
        html = html.replace("</body>", export_import_fix_script + "\n</body>", 1)
    else:
        html += "\n" + export_import_fix_script


# V42: Native import/export bridge. Does not rely on WebView file input.
native_import_export_v42 = r'''
<script>
(function(){
  if(window.__nativeImportExportV42) return;
  window.__nativeImportExportV42 = true;

  function byId(id){ return document.getElementById(id); }
  function msg(t){
    try{
      var el = byId('notifyStatus') || byId('calendarInfo') || byId('alarmStatusV30');
      if(el) el.textContent = t;
    }catch(e){}
  }

  function allLocalStorage(){
    var out = {};
    try{
      for(var i=0;i<localStorage.length;i++){
        var k = localStorage.key(i);
        out[k] = localStorage.getItem(k);
      }
    }catch(e){}
    return out;
  }

  function backupPayload(){
    return {
      app: 'Kayseri Namaz',
      backupVersion: 42,
      exportedAt: new Date().toISOString(),
      note: 'Namaz Vakti tam yedek',
      state: (typeof state !== 'undefined') ? state : null,
      tracker: (typeof tracker !== 'undefined') ? tracker : null,
      calendar: (typeof DATA !== 'undefined') ? DATA : null,
      localStorage: allLocalStorage()
    };
  }

  function doExportBackupV42(){
    try{
      var payload = backupPayload();
      var json = JSON.stringify(payload, null, 2);
      var name = 'namaz-vakti-yedek-' + new Date().toISOString().slice(0,10) + '.json';

      if(window.AndroidNotify && typeof window.AndroidNotify.saveFile === 'function'){
        window.AndroidNotify.saveFile(name, json);
        msg('Dışa aktarma için Android kaydetme ekranı açılıyor.');
        return;
      }

      var blob = new Blob([json], {type:'application/json;charset=utf-8'});
      var a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = name;
      document.body.appendChild(a);
      a.click();
      setTimeout(function(){ URL.revokeObjectURL(a.href); a.remove(); }, 1500);
      msg('Yedek dışa aktarıldı.');
    }catch(e){
      msg('Dışa aktarma hatası: ' + (e && e.message ? e.message : e));
    }
  }

  function restoreFromBackupObjectV42(data){
    if(!data || typeof data !== 'object') throw new Error('Geçersiz yedek dosyası.');

    if(data.localStorage && typeof data.localStorage === 'object'){
      Object.keys(data.localStorage).forEach(function(k){
        try{ localStorage.setItem(k, String(data.localStorage[k] == null ? '' : data.localStorage[k])); }catch(e){}
      });
    }

    try{
      if(data.calendar && Array.isArray(data.calendar)){
        if(typeof DATA !== 'undefined') DATA = data.calendar;
        if(typeof CUSTOM_DATA !== 'undefined') localStorage.setItem(CUSTOM_DATA, JSON.stringify(data.calendar));
      }

      if(data.tracker && typeof data.tracker === 'object' && typeof tracker !== 'undefined'){
        tracker = data.tracker;
      }

      if(data.state && typeof data.state === 'object' && typeof state !== 'undefined'){
        if(typeof defaults !== 'undefined') state = Object.assign({}, defaults, data.state);
        else state = data.state;
        if(state) state.activeNotify = false;
      }

      if(typeof save === 'function') save();
    }catch(e){}

    msg('Yedek içe aktarıldı. Uygulama yenileniyor...');
    setTimeout(function(){ location.reload(); }, 700);
  }

  function normalizeCalendarRowsV42(rows){
    var keys = ['date','day','sabah','sabah_sonu','ogle','ikindi','aksam','yatsi','yatsi_sonu'];
    return (rows || []).map(function(r){
      var o = {};
      keys.forEach(function(k){ o[k] = String((r && r[k]) || '').trim(); });
      return o;
    }).filter(function(r){
      return /^\d{4}-\d{2}-\d{2}$/.test(r.date) && r.sabah && r.ogle && r.yatsi_sonu;
    }).sort(function(a,b){ return a.date.localeCompare(b.date); });
  }

  function parseCsvLineV42(line, sep){
    var out = [], cur = '', q = false;
    for(var i=0;i<line.length;i++){
      var ch = line[i];
      if(ch === '"' && line[i+1] === '"'){ cur += '"'; i++; }
      else if(ch === '"'){ q = !q; }
      else if(ch === sep && !q){ out.push(cur.trim()); cur = ''; }
      else cur += ch;
    }
    out.push(cur.trim());
    return out;
  }

  function parseCalendarContentV42(text){
    text = String(text || '').trim();
    if(!text) throw new Error('Dosya boş.');

    if(text[0] === '[' || text[0] === '{'){
      var json = JSON.parse(text);
      var rows = Array.isArray(json) ? json : (json.data || json.calendar || json.rows || []);
      var arr = normalizeCalendarRowsV42(rows);
      if(!arr.length) throw new Error('JSON içinde geçerli takvim bulunamadı.');
      return arr;
    }

    var lines = text.split(/\r?\n/).filter(Boolean);
    if(!lines.length) throw new Error('CSV dosyası boş.');
    var first = lines[0] || '';
    var candidates = [';', '\t', ',', '|'];
    var sep = candidates.sort(function(a,b){ return first.split(b).length - first.split(a).length; })[0];

    var rawHeaders = parseCsvLineV42(lines.shift(), sep).map(function(h){
      return h.toLowerCase()
        .replaceAll('ı','i').replaceAll('ğ','g').replaceAll('ü','u')
        .replaceAll('ş','s').replaceAll('ö','o').replaceAll('ç','c')
        .replace(/\s+/g,'_');
    });

    function mapName(h){
      return ({
        tarih:'date', date:'date',
        gun:'day', day:'day',
        sabah:'sabah', imsak:'sabah',
        sabah_sonu:'sabah_sonu', gunes:'sabah_sonu',
        ogle:'ogle', ikindi:'ikindi', aksam:'aksam',
        yatsi:'yatsi', yatsi_sonu:'yatsi_sonu'
      })[h] || h;
    }

    var headers = rawHeaders.map(mapName);
    var rows = lines.map(function(line){
      var vals = parseCsvLineV42(line, sep);
      var o = {};
      headers.forEach(function(h,i){ o[h] = vals[i] || ''; });
      return o;
    });

    var arr = normalizeCalendarRowsV42(rows);
    if(!arr.length) throw new Error('CSV içinde geçerli takvim bulunamadı.');
    return arr;
  }

  function applyCalendarV42(text){
    var arr = parseCalendarContentV42(text);

    if(typeof DATA !== 'undefined') DATA = arr;
    if(typeof CUSTOM_DATA !== 'undefined') localStorage.setItem(CUSTOM_DATA, JSON.stringify(arr));

    try{ if(typeof initDateLimits === 'function') initDateLimits(); }catch(e){}
    try{ if(typeof renderAll === 'function') renderAll(); }catch(e){}
    try{ if(typeof scheduleReminders === 'function') scheduleReminders(); }catch(e){}
    try{ if(typeof startActiveLoop === 'function') startActiveLoop(); }catch(e){}

    var first = arr[0] && arr[0].date ? arr[0].date : '';
    var last = arr[arr.length-1] && arr[arr.length-1].date ? arr[arr.length-1].date : '';
    msg('Takvim yüklendi: ' + arr.length + ' gün' + (first && last ? ' • ' + first + ' – ' + last : ''));
  }

  function openBackupImportV42(){
    if(window.AndroidNotify && typeof window.AndroidNotify.openBackupImport === 'function'){
      window.AndroidNotify.openBackupImport();
      msg('Yedek dosyası seçiliyor...');
      return;
    }
    var input = byId('importData');
    if(input) input.click();
  }

  function openCalendarImportV42(){
    if(window.AndroidNotify && typeof window.AndroidNotify.openCalendarImport === 'function'){
      window.AndroidNotify.openCalendarImport();
      msg('Takvim dosyası seçiliyor...');
      return;
    }
    var input = byId('calendarImport');
    if(input) input.click();
  }

  window.__nativeFilePickedV42 = function(kind, name, content){
    try{
      name = String(name || '');
      content = String(content || '');

      if(kind === 'backup'){
        var data = JSON.parse(content);
        restoreFromBackupObjectV42(data);
        return;
      }

      if(kind === 'calendar'){
        var lower = name.toLowerCase();
        if(lower.endsWith('.xlsx') || lower.endsWith('.xls')){
          msg('Excel dosyası doğrudan okunmaz. JSON veya CSV seç.');
          return;
        }
        applyCalendarV42(content);
        return;
      }

      msg('Bilinmeyen dosya türü.');
    }catch(e){
      msg((kind === 'calendar' ? 'Takvim yükleme' : 'İçe aktarma') + ' hatası: ' + (e && e.message ? e.message : e));
    }
  };

  window.exportBackup = doExportBackupV42;

  function bindV42(){
    var exportBtn = byId('exportData');
    if(exportBtn) exportBtn.onclick = function(e){ if(e) e.preventDefault(); doExportBackupV42(); };

    var importBtn = byId('importBtn');
    if(importBtn) importBtn.onclick = function(e){ if(e) e.preventDefault(); openBackupImportV42(); };

    var calBtn = byId('calendarImportBtn');
    if(calBtn) calBtn.onclick = function(e){ if(e) e.preventDefault(); openCalendarImportV42(); };
  }

  setTimeout(bindV42, 200);
  setTimeout(bindV42, 1000);
  setTimeout(bindV42, 3000);
  document.addEventListener('visibilitychange', function(){ if(!document.hidden) setTimeout(bindV42, 250); });
})();
</script>
'''
if "__nativeImportExportV42" not in html:
    if "</body>" in html:
        html = html.replace("</body>", native_import_export_v42 + "\n</body>", 1)
    else:
        html += "\n" + native_import_export_v42



# V43: live notification status payload. Native service recalculates countdown every minute.
native_live_status_v43 = r'''
<script>
(function(){
  if(window.__nativeLiveStatusV43) return;
  window.__nativeLiveStatusV43 = true;

  function fix(v){
    v = String(v || '');
    v = v.replace(/Ö�le/g, "Öğle").replace(/ö�le/g, "öğle");
    v = v.replace(/G�neş/g, "Güneş").replace(/g�neş/g, "güneş");
    v = v.replace(/Yats�/g, "Yatsı").replace(/yats�/g, "yatsı");
    v = v.replace(/İkind�/g, "İkindi").replace(/ikind�/g, "ikindi");
    v = v.replace(/S�radaki/g, "Sıradaki").replace(/s�radaki/g, "sıradaki");
    return v.trim();
  }

  function valid(v){ v = fix(v); return v && v !== '-' && v !== '—' && v !== '--:--'; }
  function pad(n){ return String(n).padStart(2, '0'); }
  function todayIso(){ var d=new Date(); return d.getFullYear()+'-'+pad(d.getMonth()+1)+'-'+pad(d.getDate()); }
  function addDaysIso(iso, days){ var p=String(iso||todayIso()).split('-').map(Number); var d=new Date(p[0],p[1]-1,p[2]+days); return d.getFullYear()+'-'+pad(d.getMonth()+1)+'-'+pad(d.getDate()); }

  function recordByDate(iso){
    try{ if(typeof getRecordByDate==='function'){ var r=getRecordByDate(iso); if(r) return r; } }catch(e){}
    try{ if(Array.isArray(DATA)){ for(var i=0;i<DATA.length;i++){ if(DATA[i]&&DATA[i].date===iso) return DATA[i]; } } }catch(e){}
    return null;
  }

  function currentRec(){
    try{ if(typeof currentRecord==='function'){ var r=currentRecord(); if(r&&r.date) return r; } }catch(e){}
    return recordByDate(todayIso());
  }

  function parseMillis(date,time){
    var m=String(date+' '+time).match(/^(\d{4})-(\d{2})-(\d{2})\s+(\d{1,2}):(\d{2})/);
    if(!m) return NaN;
    return new Date(+m[1],+m[2]-1,+m[3],+m[4],+m[5],0,0).getTime();
  }

  function rem(ms){
    var min=Math.max(0,Math.ceil(ms/60000)), h=Math.floor(min/60), m=min%60;
    if(h>0) return h+' sa '+m+' dk';
    if(m>0) return m+' dk';
    return 'az kaldı';
  }

  function calc(rec,tomorrow){
    if(!rec||!rec.date) return null;
    var now=Date.now();
    var all=[['sabah','Sabah'],['sabah_sonu','Sabah sonu'],['ogle','Öğle'],['ikindi','İkindi'],['aksam','Akşam'],['yatsi','Yatsı'],['yatsi_sonu','Yatsı sonu']];
    var active='Gece';
    for(var i=0;i<all.length;i++){
      var st=parseMillis(rec.date,rec[all[i][0]]);
      var en=(i+1<all.length)?parseMillis(rec.date,rec[all[i+1][0]]):Infinity;
      if(isFinite(st)&&now>=st&&now<en){ active=all[i][1]; break; }
    }

    var upcoming=[];
    [['sabah','Sabah'],['ogle','Öğle'],['ikindi','İkindi'],['aksam','Akşam'],['yatsi','Yatsı']].forEach(function(x){
      var t=fix(rec[x[0]]); var at=parseMillis(rec.date,t);
      if(valid(t)&&isFinite(at)&&at>now) upcoming.push({label:x[1],time:t,at:at});
    });
    if(tomorrow&&tomorrow.date){
      [['sabah','Sabah'],['ogle','Öğle'],['ikindi','İkindi'],['aksam','Akşam'],['yatsi','Yatsı']].forEach(function(x){
        var t=fix(tomorrow[x[0]]); var at=parseMillis(tomorrow.date,t);
        if(valid(t)&&isFinite(at)&&at>now) upcoming.push({label:x[1],time:t,at:at});
      });
    }
    upcoming.sort(function(a,b){return a.at-b.at;});
    if(!upcoming.length) return null;

    var n=upcoming[0], r=rem(n.at-now);
    var title='Sıradaki: '+n.label+' • '+r+' kaldı';
    var lines=['Şimdi: '+active,'Sıradaki: '+n.label+' — '+n.time,'Kalan: '+r,''];
    if(valid(rec.sabah)||valid(rec.sabah_sonu)) lines.push('Sabah '+fix(rec.sabah)+(valid(rec.sabah_sonu)?' • Sabah sonu '+fix(rec.sabah_sonu):''));
    if(valid(rec.ogle)||valid(rec.ikindi)) lines.push('Öğle '+fix(rec.ogle)+(valid(rec.ikindi)?' • İkindi '+fix(rec.ikindi):''));
    if(valid(rec.aksam)||valid(rec.yatsi)) lines.push('Akşam '+fix(rec.aksam)+(valid(rec.yatsi)?' • Yatsı '+fix(rec.yatsi):''));
    if(valid(rec.yatsi_sonu)) lines.push('Yatsı sonu '+fix(rec.yatsi_sonu));
    return {title:title,body:lines.join('\n')};
  }

  function pushV43(force){
    try{
      if(typeof window.AndroidNotify==='undefined') return;
      var rec=currentRec();
      if(!rec||!rec.date) return;
      var tomorrow=recordByDate(addDaysIso(rec.date,1));
      var payload=JSON.stringify({city:'Kayseri',today:rec,tomorrow:tomorrow});
      if(typeof window.AndroidNotify.updateStatusData==='function') window.AndroidNotify.updateStatusData(payload);
      var c=calc(rec,tomorrow); if(!c) return;
      var key=c.title+'|'+c.body;
      if(!force&&window.__lastLiveStatusKeyV43===key) return;
      window.__lastLiveStatusKeyV43=key;
      window.AndroidNotify.show(c.title,JSON.stringify({body:c.body,tag:'active-prayer-summary',silent:true,status:true,requireInteraction:true}));
    }catch(e){}
  }

  window.__pushNativeStatusV43=pushV43;
  setTimeout(function(){pushV43(true);},1500);
  setTimeout(function(){pushV43(true);},5000);
  setInterval(function(){pushV43(false);},30000);
  document.addEventListener('visibilitychange',function(){if(!document.hidden)setTimeout(function(){pushV43(true);},500);});
})();
</script>
'''
if "__nativeLiveStatusV43" not in html:
    if "</body>" in html:
        html = html.replace("</body>", native_live_status_v43 + "\n</body>", 1)
    else:
        html += "\n" + native_live_status_v43


p.write_text(html, encoding="utf-8")
PY

cat > settings.gradle <<'EOF'
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories { google(); mavenCentral() }
}
rootProject.name = 'KayseriNamazVakti'
include ':app'
EOF

cat > build.gradle <<'EOF'
plugins {
    id 'com.android.application' version '8.7.3' apply false
}
EOF

cat > app/build.gradle <<'EOF'
plugins { id 'com.android.application' }

android {
    namespace 'com.turkhunmete.namazvakti'
    compileSdk 35
    defaultConfig {
        applicationId 'com.turkhunmete.namazvakti'
        minSdk 23
        targetSdk 35
        versionCode 44
        versionName '1.0.44-recovered'
    }
}
EOF

cat > app/src/main/res/values/strings.xml <<'EOF'
<resources>
    <string name="app_name">Namaz Vakti</string>
</resources>
EOF

cat > app/src/main/res/values/styles.xml <<'EOF'
<resources>
    <style name="AppTheme" parent="android:style/Theme.Material.NoActionBar">
        <item name="android:windowBackground">#000000</item>
        <item name="android:fontFamily">sans</item>
        <item name="android:colorAccent">#E6D064</item>
        <item name="android:navigationBarColor">#000000</item>
        <item name="android:statusBarColor">#000000</item>
        <item name="android:windowLightStatusBar">false</item>
        <item name="android:windowLightNavigationBar">false</item>
    </style>
</resources>
EOF

cat > app/src/main/res/drawable/ic_launcher.xml <<'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#050505" android:pathData="M0,0h108v108h-108z" />
    <group android:rotation="-10" android:pivotX="54" android:pivotY="54">
        <path
            android:fillColor="#E6D064"
            android:pathData="M72.9,9.9C59.4,14.9 49.5,27.9 49.5,44.1C49.5,68.9 69.8,89.1 94.5,89.1C85.1,95.4 73.8,99 61.7,99C36.9,99 17.1,79.2 17.1,54.5C17.1,30.6 36,10.8 59.9,9C64.4,9 68.9,9.5 72.9,9.9Z" />
    </group>
</vector>
EOF

cat > app/src/main/res/drawable/ic_stat_moon.xml <<'EOF'
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M16.2,2.2C13.2,3.3 11,6.2 11,9.8C11,15.3 15.5,19.8 21,19.8C18.9,21.2 16.4,22 13.7,22C8.2,22 3.8,17.6 3.8,12.1C3.8,6.8 8,2.4 13.3,2C14.3,2 15.3,2.1 16.2,2.2Z" />
</vector>
EOF

cat > app/src/main/AndroidManifest.xml <<'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <supports-screens android:anyDensity="true" android:smallScreens="true" android:normalScreens="true" android:largeScreens="true" android:xlargeScreens="true" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

    <application
        android:theme="@style/AppTheme"
        android:label="Namaz Vakti"
        android:icon="@drawable/ic_launcher"
        android:roundIcon="@drawable/ic_launcher"
        android:usesCleartextTraffic="true"
        android:allowBackup="true"
        android:supportsRtl="true"
        android:resizeableActivity="true">

        <activity android:name=".MainActivity" android:exported="true"
            android:resizeableActivity="true"
            android:configChanges="screenSize|smallestScreenSize|screenLayout|orientation|keyboardHidden">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service android:name=".StatusService" android:exported="false" android:foregroundServiceType="dataSync" />
        <receiver android:name=".WatchdogReceiver" android:exported="false" />
        <receiver android:name=".AlarmReceiver" android:exported="false" />

        <receiver android:name=".BootReceiver" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            </intent-filter>
        </receiver>
    </application>
</manifest>
EOF

cat > app/src/main/java/com/turkhunmete/namazvakti/TextFix.java <<'EOF'
package com.turkhunmete.namazvakti;

public class TextFix {
    public static String normalize(String text) {
        if (text == null) return "";
        String x = text.replace("\\n", "\n").replace("\\r", "\n").replace("\r", "\n");
        x = x.replace("Ö�le", "Öğle").replace("ö�le", "öğle");
        x = x.replace("G�neş", "Güneş").replace("g�neş", "güneş");
        x = x.replace("Yats�", "Yatsı").replace("yats�", "yatsı");
        x = x.replace("S�radaki", "Sıradaki").replace("s�radaki", "sıradaki");
        x = x.replace("Kald�", "Kaldı").replace("kald�", "kaldı");
        x = x.replace("s�re", "süre").replace("S�re", "Süre");
        x = x.replace("g�n", "gün").replace("G�n", "Gün");
        return x.trim();
    }

    public static String compact(String text, int max) {
        String clean = normalize(text).replace("\n", " ").replace("  ", " ").trim();
        if (clean.length() <= max) return clean;
        return clean.substring(0, Math.max(0, max - 3)).trim() + "...";
    }
}
EOF

cat > app/src/main/java/com/turkhunmete/namazvakti/Watchdog.java <<'EOF'
package com.turkhunmete.namazvakti;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.SystemClock;

public class Watchdog {
    public static final String ACTION_WATCHDOG = "com.turkhunmete.namazvakti.WATCHDOG";
    private static final int REQUEST_CODE = 2900;

    public static void schedule(Context context) {
        if (context == null) return;
        Intent intent = new Intent(context, WatchdogReceiver.class);
        intent.setAction(ACTION_WATCHDOG);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
        PendingIntent pendingIntent = PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags);
        AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarmManager == null) return;
        long triggerAt = SystemClock.elapsedRealtime() + 90000;
        try {
            if (Build.VERSION.SDK_INT >= 23) alarmManager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent);
            else alarmManager.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent);
        } catch (Exception ignored) {}
    }
}
EOF

cat > app/src/main/java/com/turkhunmete/namazvakti/WatchdogReceiver.java <<'EOF'
package com.turkhunmete.namazvakti;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

public class WatchdogReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        if (context == null) return;
        Watchdog.schedule(context);
        Intent serviceIntent = new Intent(context, StatusService.class);
        serviceIntent.putExtra("restoreOnly", true);
        try {
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(serviceIntent);
            else context.startService(serviceIntent);
        } catch (Exception ignored) {}
    }
}
EOF

cat > app/src/main/java/com/turkhunmete/namazvakti/BootReceiver.java <<'EOF'
package com.turkhunmete.namazvakti;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

public class BootReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        if (context == null || intent == null) return;
        String action = intent.getAction();
        if (Intent.ACTION_BOOT_COMPLETED.equals(action) || Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)) {
            Watchdog.schedule(context);
            AlarmScheduler.reschedule(context);
            Intent serviceIntent = new Intent(context, StatusService.class);
            serviceIntent.putExtra("restoreOnly", true);
            try {
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(serviceIntent);
                else context.startService(serviceIntent);
            } catch (Exception ignored) {}
        }
    }
}
EOF

cat > app/src/main/java/com/turkhunmete/namazvakti/AlarmScheduler.java <<'EOF'
package com.turkhunmete.namazvakti;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;

import org.json.JSONArray;
import org.json.JSONObject;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public class AlarmScheduler {
    public static final String CHANNEL_ALARM_SILENT = "namaz_vakti_alarm_v29_silent";
    public static final String CHANNEL_ALARM_VIBRATE = "namaz_vakti_alarm_v29_vibrate";
    public static final String CHANNEL_ALARM_SOUND = "namaz_vakti_alarm_v29_sound";

    public static void configure(Context context, String json) {
        if (context == null || json == null || json.trim().length() == 0) return;
        SharedPreferences prefs = context.getSharedPreferences("alarms", Context.MODE_PRIVATE);
        String oldJson = prefs.getString("json", "");
        cancelFromJson(context, oldJson);
        cancelFromJson(context, json);
        prefs.edit().putString("json", json).apply();
        scheduleFromJson(context, json);
    }

    public static void reschedule(Context context) {
        if (context == null) return;
        SharedPreferences prefs = context.getSharedPreferences("alarms", Context.MODE_PRIVATE);
        String json = prefs.getString("json", "");
        if (json != null && json.trim().length() > 0) scheduleFromJson(context, json);
    }

    public static void ensureChannels(Context context) {
        if (context == null || Build.VERSION.SDK_INT < 26) return;
        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager == null) return;

        NotificationChannel silent = new NotificationChannel(CHANNEL_ALARM_SILENT, "Namaz Alarmları - Sessiz", NotificationManager.IMPORTANCE_DEFAULT);
        silent.setDescription("Sessiz vakit bildirimleri");
        silent.enableVibration(false);
        silent.setSound(null, null);
        silent.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);

        NotificationChannel vibrate = new NotificationChannel(CHANNEL_ALARM_VIBRATE, "Namaz Alarmları - Titreşimli", NotificationManager.IMPORTANCE_HIGH);
        vibrate.setDescription("Titreşimli vakit bildirimleri");
        vibrate.enableVibration(true);
        vibrate.setVibrationPattern(new long[]{0, 250, 120, 250});
        vibrate.setSound(null, null);
        vibrate.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);

        NotificationChannel sound = new NotificationChannel(CHANNEL_ALARM_SOUND, "Namaz Alarmları - Sesli", NotificationManager.IMPORTANCE_HIGH);
        sound.setDescription("Sesli ve titreşimli vakit bildirimleri");
        sound.enableVibration(true);
        sound.setVibrationPattern(new long[]{0, 250, 120, 250});
        sound.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);

        manager.createNotificationChannel(silent);
        manager.createNotificationChannel(vibrate);
        manager.createNotificationChannel(sound);
    }

    public static String channelForMode(String mode) {
        mode = mode == null ? "vibrate" : mode;
        if ("silent".equals(mode)) return CHANNEL_ALARM_SILENT;
        if ("sound".equals(mode)) return CHANNEL_ALARM_SOUND;
        return CHANNEL_ALARM_VIBRATE;
    }

    public static void showTest(Context context, String json) {
        if (context == null) return;
        ensureChannels(context);
        try {
            JSONObject root = new JSONObject(json == null ? "{}" : json);
            String city = TextFix.normalize(root.optString("city", "Kayseri"));
            String label = TextFix.normalize(root.optString("label", "Öğle"));
            String time = TextFix.normalize(root.optString("time", "12:37"));
            String mode = root.optString("mode", "vibrate");
            String style = root.optString("style", "detailed");
            String[] tb = compose(city, label, time, "time", 0, style);
            Intent i = new Intent(context, AlarmReceiver.class);
            i.putExtra("title", tb[0]);
            i.putExtra("body", tb[1]);
            i.putExtra("mode", mode);
            new AlarmReceiver().onReceive(context, i);
        } catch (Exception ignored) {}
    }

    private static void scheduleFromJson(Context context, String json) {
        ensureChannels(context);
        try {
            JSONObject root = new JSONObject(json);
            int preMinutes = root.optInt("preMinutes", 10);
            String mode = root.optString("mode", "vibrate");
            String style = root.optString("style", "detailed");
            String city = TextFix.normalize(root.optString("city", "Kayseri"));
            JSONArray prayers = root.optJSONArray("prayers");
            if (prayers == null) return;

            long now = System.currentTimeMillis();
            for (int i = 0; i < prayers.length(); i++) {
                JSONObject p = prayers.optJSONObject(i);
                if (p == null) continue;

                String date = p.optString("date", "");
                String key = p.optString("key", "");
                String label = TextFix.normalize(p.optString("label", ""));
                String time = TextFix.normalize(p.optString("time", ""));
                if (date.length() == 0 || key.length() == 0 || label.length() == 0 || time.length() == 0) continue;

                long at = parseMillis(date, time);
                if (at <= 0) continue;

                if (at > now + 30000) {
                    String[] tb = compose(city, label, time, "time", preMinutes, style);
                    scheduleOne(context, at, tb[0], tb[1], mode, date + key + "time");
                }

                long preAt = at - (preMinutes * 60L * 1000L);
                if (preMinutes > 0 && preAt > now + 30000) {
                    String[] tb = compose(city, label, time, "pre", preMinutes, style);
                    scheduleOne(context, preAt, tb[0], tb[1], mode, date + key + "pre");
                }
            }
        } catch (Exception ignored) {}
    }

    private static String[] compose(String city, String label, String time, String type, int preMinutes, String style) {
        city = city == null || city.length() == 0 ? "Kayseri" : city;
        label = TextFix.normalize(label);
        time = TextFix.normalize(time);
        style = style == null ? "detailed" : style;

        boolean isPre = "pre".equals(type);
        String title = isPre ? label + "'ye " + preMinutes + " dk kaldı" : label + " vakti";
        String body;

        if ("simple".equals(style)) {
            body = isPre ? city + " • " + label + " vakti " + time : city + " • " + time;
        } else if ("manevi".equals(style)) {
            body = isPre
                    ? label + " vaktine " + preMinutes + " dakika kaldı.\nHazırlık vakti. " + city + " • " + time
                    : label + " vakti girdi.\nHaydi namaza. " + city + " • " + time;
        } else {
            body = isPre
                    ? city + " • " + label + " vakti " + time + ".\n" + preMinutes + " dakika sonra vakit girecek."
                    : city + " • " + label + " vakti girdi. Saat: " + time + "\nÇeteleye işaretlemek için uygulamayı açabilirsin.";
        }

        return new String[]{TextFix.normalize(title), TextFix.normalize(body)};
    }

    private static void cancelFromJson(Context context, String json) {
        if (context == null || json == null || json.trim().length() == 0) return;
        try {
            JSONObject root = new JSONObject(json);
            JSONArray prayers = root.optJSONArray("prayers");
            if (prayers == null) return;
            for (int i = 0; i < prayers.length(); i++) {
                JSONObject p = prayers.optJSONObject(i);
                if (p == null) continue;
                String date = p.optString("date", "");
                String key = p.optString("key", "");
                String label = TextFix.normalize(p.optString("label", ""));
                if (date.length() == 0) continue;
                if (key.length() > 0) {
                    cancelOne(context, date + key + "time");
                    cancelOne(context, date + key + "pre");
                }
                if (label.length() > 0) {
                    cancelOne(context, date + label + "time");
                    cancelOne(context, date + label + "pre");
                }
            }
        } catch (Exception ignored) {}
    }

    private static long parseMillis(String date, String time) {
        try {
            SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US);
            Date d = sdf.parse(date + " " + time);
            return d == null ? 0 : d.getTime();
        } catch (Exception e) { return 0; }
    }

    private static void scheduleOne(Context context, long triggerAtMillis, String title, String body, String mode, String key) {
        Intent intent = new Intent(context, AlarmReceiver.class);
        intent.putExtra("title", title);
        intent.putExtra("body", body);
        intent.putExtra("mode", mode == null ? "vibrate" : mode);

        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
        int requestCode = Math.abs(key.hashCode());
        PendingIntent pi = PendingIntent.getBroadcast(context, requestCode, intent, flags);

        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;

        try {
            if (Build.VERSION.SDK_INT >= 31) {
                if (am.canScheduleExactAlarms()) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi);
                } else {
                    Intent openIntent = new Intent(context, MainActivity.class);
                    openIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                    PendingIntent showIntent = PendingIntent.getActivity(context, requestCode + 1000000, openIntent, flags);
                    am.setAlarmClock(new AlarmManager.AlarmClockInfo(triggerAtMillis, showIntent), pi);
                }
            } else if (Build.VERSION.SDK_INT >= 23) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi);
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi);
            }
        } catch (Exception e) {
            try {
                if (Build.VERSION.SDK_INT >= 23) am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi);
                else am.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi);
            } catch (Exception ignored) {}
        }
    }

    private static void cancelOne(Context context, String key) {
        try {
            Intent intent = new Intent(context, AlarmReceiver.class);
            int flags = PendingIntent.FLAG_UPDATE_CURRENT;
            if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
            PendingIntent pi = PendingIntent.getBroadcast(context, Math.abs(key.hashCode()), intent, flags);
            AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (am != null) am.cancel(pi);
            pi.cancel();
        } catch (Exception ignored) {}
    }
}
EOF

cat > app/src/main/java/com/turkhunmete/namazvakti/AlarmReceiver.java <<'EOF'
package com.turkhunmete.namazvakti;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;

public class AlarmReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        if (context == null || intent == null) return;
        AlarmScheduler.ensureChannels(context);

        String title = TextFix.normalize(intent.getStringExtra("title"));
        String body = TextFix.normalize(intent.getStringExtra("body"));
        String mode = intent.getStringExtra("mode");
        if (mode == null || mode.length() == 0) mode = "vibrate";
        if (title.length() == 0) title = "Namaz Vakti";

        Intent openIntent = new Intent(context, MainActivity.class);
        openIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
        PendingIntent contentIntent = PendingIntent.getActivity(context, 0, openIntent, flags);

        Notification.Builder b;
        if (Build.VERSION.SDK_INT >= 26) {
            b = new Notification.Builder(context, AlarmScheduler.channelForMode(mode));
        } else {
            b = new Notification.Builder(context);
            b.setPriority("silent".equals(mode) ? Notification.PRIORITY_DEFAULT : Notification.PRIORITY_HIGH);
        }

        b.setSmallIcon(R.drawable.ic_stat_moon)
                .setContentTitle(title)
                .setContentText(TextFix.compact(body, 58))
                .setStyle(new Notification.BigTextStyle().bigText(body))
                .setContentIntent(contentIntent)
                .setAutoCancel(true)
                .setOngoing(false)
                .setShowWhen(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setColor(Color.rgb(230, 208, 100));

        if (Build.VERSION.SDK_INT < 26) {
            if ("silent".equals(mode)) {
                b.setSound(null);
                b.setVibrate(new long[]{0});
            } else if ("vibrate".equals(mode)) {
                b.setSound(null);
                b.setVibrate(new long[]{0, 250, 120, 250});
            } else {
                b.setDefaults(Notification.DEFAULT_SOUND | Notification.DEFAULT_VIBRATE);
            }
        } else {
            if ("silent".equals(mode)) b.setVibrate(new long[]{0});
            else b.setVibrate(new long[]{0, 250, 120, 250});
        }

        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager != null) manager.notify((int)(System.currentTimeMillis() % 100000), b.build());

        Watchdog.schedule(context);
        AlarmScheduler.reschedule(context);
    }
}
EOF

cat > app/src/main/java/com/turkhunmete/namazvakti/MainActivity.java <<'EOF'
package com.turkhunmete.namazvakti;

import android.Manifest;
import android.app.Activity;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.ClipData;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebChromeClient;
import android.webkit.WebViewClient;
import android.widget.Toast;

import java.io.OutputStream;
import java.io.InputStream;
import java.io.ByteArrayOutputStream;

import org.json.JSONObject;

public class MainActivity extends Activity {
    private WebView webView;
    private ValueCallback<Uri[]> filePathCallback;
    private static final int FILE_CHOOSER_REQUEST = 3701;
    private static final int EXPORT_FILE_REQUEST = 3802;
    private static final int IMPORT_BACKUP_REQUEST = 4203;
    private static final int IMPORT_CALENDAR_REQUEST = 4204;
    private String pendingExportName;
    private String pendingExportContent;
    public static final String CHANNEL_ALERT = "namaz_vakti_alert_channel";
    public static final String CHANNEL_STATUS = "namaz_vakti_status_channel_v37_full_public";

    @Override protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(Color.BLACK);
        getWindow().setNavigationBarColor(Color.BLACK);
        createNotificationChannels();
        AlarmScheduler.ensureChannels(this);

        webView = new WebView(this);
        webView.setBackgroundColor(Color.BLACK);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setMediaPlaybackRequiresUserGesture(false);

        webView.setWebViewClient(new WebViewClient());
        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView webView, ValueCallback<Uri[]> filePathCallback, WebChromeClient.FileChooserParams fileChooserParams) {
                if (MainActivity.this.filePathCallback != null) {
                    MainActivity.this.filePathCallback.onReceiveValue(null);
                }
                MainActivity.this.filePathCallback = filePathCallback;

                Intent intent;
                try {
                    intent = fileChooserParams.createIntent();
                } catch (Exception e) {
                    intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                    intent.addCategory(Intent.CATEGORY_OPENABLE);
                    intent.setType("*/*");
                    intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"application/json", "text/csv", "text/*"});
                }

                try {
                    startActivityForResult(intent, FILE_CHOOSER_REQUEST);
                } catch (Exception e) {
                    try {
                        Intent fallback = new Intent(Intent.ACTION_GET_CONTENT);
                        fallback.addCategory(Intent.CATEGORY_OPENABLE);
                        fallback.setType("*/*");
                        fallback.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"application/json", "text/csv", "text/*"});
                        startActivityForResult(Intent.createChooser(fallback, "Dosya seç"), FILE_CHOOSER_REQUEST);
                    } catch (Exception ignored) {
                        MainActivity.this.filePathCallback = null;
                        filePathCallback.onReceiveValue(null);
                        return false;
                    }
                }
                return true;
            }
        });
        webView.addJavascriptInterface(new AndroidNotifyBridge(), "AndroidNotify");
        setContentView(webView);
        webView.loadUrl("file:///android_asset/index.html");
        Watchdog.schedule(this);

        new Handler(Looper.getMainLooper()).postDelayed(new Runnable() { @Override public void run() {
            ensureNotificationPermissionThenStartStatus();
            pushFromWeb();
        }}, 1800);
        new Handler(Looper.getMainLooper()).postDelayed(new Runnable() { @Override public void run() { pushFromWeb(); }}, 5000);
    }

    private void pushFromWeb() {
        try {
            if (webView != null) webView.evaluateJavascript("try{window.__pushNativeStatusV30&&window.__pushNativeStatusV30(true);window.__pushNativeAlarmsV30&&window.__pushNativeAlarmsV30(true)}catch(e){}", null);
        } catch (Exception ignored) {}
    }

    private boolean hasNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33) return checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED;
        return true;
    }

    private void ensureNotificationPermissionThenStartStatus() {
        if (hasNotificationPermission()) { startStatusService(null, null, true); return; }
        if (Build.VERSION.SDK_INT >= 33) requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 1002);
    }

    private void requestNotificationPermissionOnly() {
        if (Build.VERSION.SDK_INT >= 33 && !hasNotificationPermission()) requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 1002);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {

        if (requestCode == IMPORT_BACKUP_REQUEST || requestCode == IMPORT_CALENDAR_REQUEST) {
            if (resultCode == RESULT_OK && data != null && data.getData() != null) {
                try {
                    Uri uri = data.getData();
                    String content = readTextFromUri(uri);
                    String name = uri == null ? "dosya.json" : uri.toString();
                    String kind = requestCode == IMPORT_BACKUP_REQUEST ? "backup" : "calendar";
                    final String js = "try{window.__nativeFilePickedV42&&window.__nativeFilePickedV42("
                            + JSONObject.quote(kind) + ","
                            + JSONObject.quote(name) + ","
                            + JSONObject.quote(content)
                            + ")}catch(e){}";
                    if (webView != null) {
                        webView.evaluateJavascript(js, null);
                    }
                } catch (Exception e) {
                    setWebStatus("Dosya okunamadı: " + e.getMessage());
                    Toast.makeText(this, "Dosya okunamadı: " + e.getMessage(), Toast.LENGTH_LONG).show();
                }
            } else {
                setWebStatus("Dosya seçimi iptal edildi.");
            }
            return;
        }

        if (requestCode == EXPORT_FILE_REQUEST) {
            if (resultCode == RESULT_OK && data != null && data.getData() != null && pendingExportContent != null) {
                try {
                    OutputStream os = getContentResolver().openOutputStream(data.getData());
                    if (os != null) {
                        os.write(pendingExportContent.getBytes("UTF-8"));
                        os.flush();
                        os.close();
                    }
                    Toast.makeText(this, "Yedek kaydedildi", Toast.LENGTH_SHORT).show();
                    setWebStatus("Yedek dışa aktarıldı.");
                } catch (Exception e) {
                    Toast.makeText(this, "Kaydetme hatası: " + e.getMessage(), Toast.LENGTH_LONG).show();
                    setWebStatus("Dışa aktarma hatası: " + e.getMessage());
                }
            } else {
                setWebStatus("Dışa aktarma iptal edildi.");
            }
            pendingExportName = null;
            pendingExportContent = null;
            return;
        }

        if (requestCode == FILE_CHOOSER_REQUEST) {
            Uri[] results = null;

            if (resultCode == RESULT_OK && data != null) {
                String dataString = data.getDataString();
                ClipData clipData = data.getClipData();

                if (clipData != null) {
                    int count = clipData.getItemCount();
                    results = new Uri[count];
                    for (int i = 0; i < count; i++) {
                        results[i] = clipData.getItemAt(i).getUri();
                    }
                } else if (dataString != null) {
                    results = new Uri[]{Uri.parse(dataString)};
                }
            }

            if (filePathCallback != null) {
                filePathCallback.onReceiveValue(results);
                filePathCallback = null;
            }
            return;
        }

        super.onActivityResult(requestCode, resultCode, data);
    }

    @Override public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == 1002 && hasNotificationPermission()) {
            startStatusService(null, null, true);
            Watchdog.schedule(this);
            pushFromWeb();
        }
    }

    private void createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            NotificationChannel alertChannel = new NotificationChannel(CHANNEL_ALERT, "Namaz Vakti Hatırlatmaları", NotificationManager.IMPORTANCE_HIGH);
            alertChannel.setDescription("Sesli namaz vakti hatırlatmaları");
            alertChannel.enableVibration(true);
            alertChannel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            NotificationChannel statusChannel = new NotificationChannel(CHANNEL_STATUS, "Namaz Vakti Tüm Vakitler Özeti", NotificationManager.IMPORTANCE_DEFAULT);
            statusChannel.setDescription("Sessiz kalıcı tüm vakit özeti");
            statusChannel.enableVibration(false);
            statusChannel.setSound(null, null);
            statusChannel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            if (manager != null) { manager.createNotificationChannel(alertChannel); manager.createNotificationChannel(statusChannel); }
        }
    }

    private void startStatusService(String title, String body, boolean restoreOnly) {
        Intent serviceIntent = new Intent(this, StatusService.class);
        if (restoreOnly) serviceIntent.putExtra("restoreOnly", true);
        else { serviceIntent.putExtra("title", TextFix.normalize(title)); serviceIntent.putExtra("body", TextFix.normalize(body)); }
        try {
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(serviceIntent);
            else startService(serviceIntent);
        } catch (Exception ignored) {}
        Watchdog.schedule(this);
    }


    private void updateStatusPayload(String payloadJson) {
        Intent serviceIntent = new Intent(this, StatusService.class);
        serviceIntent.putExtra("statusData", payloadJson == null ? "" : payloadJson);
        try {
            if (Build.VERSION.SDK_INT >= 26) startForegroundService(serviceIntent);
            else startService(serviceIntent);
        } catch (Exception ignored) {}
        Watchdog.schedule(this);
    }

    private void showNativeNotification(String title, String optionsJson) {
        if (!hasNotificationPermission()) { requestNotificationPermissionOnly(); return; }
        String body = "";
        boolean silent = false, hasTag = false, status = false;
        try {
            JSONObject options = new JSONObject(optionsJson == null ? "{}" : optionsJson);
            body = options.optString("body", "");
            silent = options.optBoolean("silent", false);
            hasTag = options.has("tag");
            status = options.optBoolean("status", false);
        } catch (Exception ignored) {}
        String finalTitle = TextFix.normalize(title);
        if (finalTitle.length() == 0) finalTitle = "Namaz Vakti";
        body = TextFix.normalize(body);
        if (silent || hasTag || status) { startStatusService(finalTitle, body, false); return; }

        Intent intent = new Intent(this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, intent, flags);

        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= 26) builder = new Notification.Builder(this, CHANNEL_ALERT);
        else { builder = new Notification.Builder(this); builder.setPriority(Notification.PRIORITY_HIGH); }

        builder.setSmallIcon(R.drawable.ic_stat_moon)
                .setContentTitle(finalTitle)
                .setContentText(TextFix.compact(body, 58))
                .setStyle(new Notification.BigTextStyle().bigText(body))
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .setOngoing(false)
                .setShowWhen(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setColor(Color.rgb(230, 208, 100))
                .setVibrate(new long[]{0, 180, 90, 180});

        NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        if (manager != null) manager.notify((int)(System.currentTimeMillis() % 100000), builder.build());
    }

    private void setWebStatus(String message) {
        try {
            if (webView != null) {
                webView.evaluateJavascript(
                        "try{var e=document.getElementById('notifyStatus')||document.getElementById('calendarInfo')||document.getElementById('alarmStatusV30');if(e)e.textContent=" + JSONObject.quote(message == null ? "" : message) + ";}catch(x){}",
                        null
                );
            }
        } catch (Exception ignored) {}
    }


    private String readTextFromUri(Uri uri) throws Exception {
        InputStream input = getContentResolver().openInputStream(uri);
        if (input == null) return "";
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        byte[] data = new byte[8192];
        int n;
        while ((n = input.read(data)) != -1) {
            buffer.write(data, 0, n);
        }
        input.close();
        return buffer.toString("UTF-8");
    }

    private void openNativeFilePicker(int requestCode, String title) {
        try {
            Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("*/*");
            intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{
                    "application/json",
                    "text/csv",
                    "text/comma-separated-values",
                    "text/plain",
                    "application/octet-stream"
            });
            startActivityForResult(Intent.createChooser(intent, title), requestCode);
        } catch (Exception e) {
            Toast.makeText(this, "Dosya seçici açılamadı: " + e.getMessage(), Toast.LENGTH_LONG).show();
            setWebStatus("Dosya seçici açılamadı: " + e.getMessage());
        }
    }

    private void saveExportFile(String filename, String content) {
        pendingExportName = (filename == null || filename.trim().length() == 0) ? "namaz-vakti-yedek.json" : filename.trim();
        pendingExportContent = content == null ? "{}" : content;

        try {
            Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("application/json");
            intent.putExtra(Intent.EXTRA_TITLE, pendingExportName);
            startActivityForResult(intent, EXPORT_FILE_REQUEST);
        } catch (Exception e) {
            Toast.makeText(this, "Dosya kaydetme ekranı açılamadı: " + e.getMessage(), Toast.LENGTH_LONG).show();
            setWebStatus("Dosya kaydetme ekranı açılamadı: " + e.getMessage());
        }
    }

    public class AndroidNotifyBridge {
        @JavascriptInterface public String permissionState() { return hasNotificationPermission() ? "granted" : "default"; }
        @JavascriptInterface public String requestPermission() { runOnUiThread(new Runnable() { @Override public void run() { requestNotificationPermissionOnly(); }}); return hasNotificationPermission() ? "granted" : "default"; }
        @JavascriptInterface public void show(final String title, final String optionsJson) { runOnUiThread(new Runnable() { @Override public void run() { showNativeNotification(title, optionsJson); }}); }
        @JavascriptInterface public void scheduleAlarms(final String payloadJson) { runOnUiThread(new Runnable() { @Override public void run() { AlarmScheduler.configure(MainActivity.this, payloadJson); }}); }
        @JavascriptInterface public void testAlarm(final String payloadJson) { runOnUiThread(new Runnable() { @Override public void run() { AlarmScheduler.showTest(MainActivity.this, payloadJson); }}); }
        @JavascriptInterface public void saveFile(final String filename, final String content) { runOnUiThread(new Runnable() { @Override public void run() { saveExportFile(filename, content); }}); }
        @JavascriptInterface public void openBackupImport() { runOnUiThread(new Runnable() { @Override public void run() { openNativeFilePicker(IMPORT_BACKUP_REQUEST, "Yedek dosyası seç"); }}); }
        @JavascriptInterface public void openCalendarImport() { runOnUiThread(new Runnable() { @Override public void run() { openNativeFilePicker(IMPORT_CALENDAR_REQUEST, "Takvim dosyası seç"); }}); }
    }

    @Override public void onBackPressed() {
        if (webView != null && webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }
}
EOF


cat > app/src/main/java/com/turkhunmete/namazvakti/StatusCalculator.java <<'EOF'
package com.turkhunmete.namazvakti;

import org.json.JSONObject;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.Locale;

public class StatusCalculator {
    public static class Result {
        public String title;
        public String body;
        Result(String t, String b) { title = t; body = b; }
    }

    private static class PrayerTime {
        String label, time;
        long at;
        PrayerTime(String l, String t, long a) { label = l; time = t; at = a; }
    }

    private static long parseMillis(String date, String time) {
        try {
            SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.US);
            Date d = sdf.parse(date + " " + time);
            return d == null ? 0 : d.getTime();
        } catch (Exception e) { return 0; }
    }

    private static String opt(JSONObject o, String k) { return TextFix.normalize(o == null ? "" : o.optString(k, "")); }
    private static boolean valid(String s) {
        s = TextFix.normalize(s);
        return s.length() > 0 && !"-".equals(s) && !"—".equals(s) && !"--:--".equals(s);
    }

    private static String remainingText(long ms) {
        long min = Math.max(0, (ms + 59999L) / 60000L);
        long h = min / 60L;
        long m = min % 60L;
        if (h > 0) return h + " sa " + m + " dk";
        if (m > 0) return m + " dk";
        return "az kaldı";
    }

    public static Result calculate(String statusData, String fallbackTitle, String fallbackBody) {
        try {
            if (statusData == null || statusData.trim().length() == 0) return new Result(fallbackTitle, fallbackBody);

            JSONObject root = new JSONObject(statusData);
            JSONObject today = root.optJSONObject("today");
            JSONObject tomorrow = root.optJSONObject("tomorrow");
            if (today == null) return new Result(fallbackTitle, fallbackBody);

            String date = opt(today, "date");
            long now = System.currentTimeMillis();

            String[][] all = {{"sabah","Sabah"},{"sabah_sonu","Sabah sonu"},{"ogle","Öğle"},{"ikindi","İkindi"},{"aksam","Akşam"},{"yatsi","Yatsı"},{"yatsi_sonu","Yatsı sonu"}};
            String active = "Gece";
            for (int i = 0; i < all.length; i++) {
                long start = parseMillis(date, opt(today, all[i][0]));
                long end = Long.MAX_VALUE;
                if (i + 1 < all.length) end = parseMillis(date, opt(today, all[i + 1][0]));
                if (start > 0 && now >= start && now < end) { active = all[i][1]; break; }
            }

            ArrayList<PrayerTime> upcoming = new ArrayList<>();
            String[][] prayers = {{"sabah","Sabah"},{"ogle","Öğle"},{"ikindi","İkindi"},{"aksam","Akşam"},{"yatsi","Yatsı"}};

            for (String[] pr : prayers) {
                String t = opt(today, pr[0]);
                long at = parseMillis(date, t);
                if (valid(t) && at > now) upcoming.add(new PrayerTime(pr[1], t, at));
            }

            if (tomorrow != null) {
                String tomorrowDate = opt(tomorrow, "date");
                for (String[] pr : prayers) {
                    String t = opt(tomorrow, pr[0]);
                    long at = parseMillis(tomorrowDate, t);
                    if (valid(t) && at > now) upcoming.add(new PrayerTime(pr[1], t, at));
                }
            }

            if (upcoming.size() == 0) return new Result(fallbackTitle, fallbackBody);

            Collections.sort(upcoming, new Comparator<PrayerTime>() {
                @Override public int compare(PrayerTime a, PrayerTime b) { return Long.compare(a.at, b.at); }
            });

            PrayerTime next = upcoming.get(0);
            String rem = remainingText(next.at - now);
            String title = "Sıradaki: " + next.label + " • " + rem + " kaldı";

            String sabah = opt(today, "sabah");
            String sabahSonu = opt(today, "sabah_sonu");
            String ogle = opt(today, "ogle");
            String ikindi = opt(today, "ikindi");
            String aksam = opt(today, "aksam");
            String yatsi = opt(today, "yatsi");
            String yatsiSonu = opt(today, "yatsi_sonu");

            StringBuilder body = new StringBuilder();
            body.append("Şimdi: ").append(active).append("\n");
            body.append("Sıradaki: ").append(next.label).append(" — ").append(next.time).append("\n");
            body.append("Kalan: ").append(rem).append("\n\n");
            if (valid(sabah) || valid(sabahSonu)) body.append("Sabah ").append(sabah).append(valid(sabahSonu) ? " • Sabah sonu " + sabahSonu : "").append("\n");
            if (valid(ogle) || valid(ikindi)) body.append("Öğle ").append(ogle).append(valid(ikindi) ? " • İkindi " + ikindi : "").append("\n");
            if (valid(aksam) || valid(yatsi)) body.append("Akşam ").append(aksam).append(valid(yatsi) ? " • Yatsı " + yatsi : "").append("\n");
            if (valid(yatsiSonu)) body.append("Yatsı sonu ").append(yatsiSonu);

            return new Result(TextFix.normalize(title), TextFix.normalize(body.toString()));
        } catch (Exception e) { return new Result(fallbackTitle, fallbackBody); }
    }
}
EOF

cat > app/src/main/java/com/turkhunmete/namazvakti/StatusService.java <<'EOF'
package com.turkhunmete.namazvakti;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ServiceInfo;
import android.graphics.Color;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;

public class StatusService extends Service {
    private static final int STATUS_NOTIFICATION_ID = 1000;
    private Handler handler;
    private Runnable ticker;
    private String currentTitle = "Namaz Vakti";
    private String currentBody = "Uygulamayı açınca aktif özet güncellenecek.";
    private String statusData = "";

    @Override public void onCreate() {
        super.onCreate();
        createChannels();
        loadSavedStatus();
        handler = new Handler(Looper.getMainLooper());
        ticker = new Runnable() { @Override public void run() {
            try { showForegroundNotification(); } catch (Exception ignored) {}
            Watchdog.schedule(StatusService.this);
            if (handler != null) handler.postDelayed(this, 60000);
        }};
    }

    private void loadSavedStatus() {
        SharedPreferences prefs = getSharedPreferences("status", MODE_PRIVATE);
        currentTitle = TextFix.normalize(prefs.getString("title", currentTitle));
        currentBody = TextFix.normalize(prefs.getString("body", currentBody));
        statusData = prefs.getString("statusData", statusData);
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        loadSavedStatus();
        boolean restoreOnly = intent != null && intent.getBooleanExtra("restoreOnly", false);

        if (intent != null) {
            String incomingStatus = intent.getStringExtra("statusData");
            if (incomingStatus != null && incomingStatus.trim().length() > 0) {
                statusData = incomingStatus;
                getSharedPreferences("status", MODE_PRIVATE).edit().putString("statusData", statusData).apply();
            }

            if (!restoreOnly) {
                String title = TextFix.normalize(intent.getStringExtra("title"));
                String body = TextFix.normalize(intent.getStringExtra("body"));
                if (title.length() > 0) currentTitle = title;
                if (body.length() > 0) currentBody = body;
                getSharedPreferences("status", MODE_PRIVATE).edit().putString("title", currentTitle).putString("body", currentBody).apply();
            }
        }

        try { showForegroundNotification(); } catch (Exception ignored) {}
        Watchdog.schedule(this);
        if (handler != null && ticker != null) {
            handler.removeCallbacks(ticker);
            handler.postDelayed(ticker, 60000);
        }
        return START_STICKY;
    }

    private void createChannels() {
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            NotificationChannel statusChannel = new NotificationChannel(MainActivity.CHANNEL_STATUS, "Namaz Vakti Canlı Özet", NotificationManager.IMPORTANCE_DEFAULT);
            statusChannel.setDescription("Dakikada bir güncellenen sessiz aktif vakit özeti");
            statusChannel.enableVibration(false);
            statusChannel.setSound(null, null);
            statusChannel.setLockscreenVisibility(Notification.VISIBILITY_PUBLIC);
            if (manager != null) manager.createNotificationChannel(statusChannel);
        }
    }

    private String compactText(String text) {
        String clean = TextFix.normalize(text).replace("
", " ").replace("  ", " ").trim();
        if (clean.length() <= 58) return clean;
        return clean.substring(0, 55).trim() + "...";
    }

    private void showForegroundNotification() {
        StatusCalculator.Result calc = StatusCalculator.calculate(statusData, currentTitle, currentBody);
        String title = calc.title == null || calc.title.length() == 0 ? "Namaz Vakti" : calc.title;
        String body = calc.body == null || calc.body.length() == 0 ? currentBody : calc.body;

        Intent intent = new Intent(this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, intent, flags);

        Notification.Builder builder;
        if (Build.VERSION.SDK_INT >= 26) builder = new Notification.Builder(this, MainActivity.CHANNEL_STATUS);
        else { builder = new Notification.Builder(this); builder.setPriority(Notification.PRIORITY_DEFAULT); }

        builder.setSmallIcon(R.drawable.ic_stat_moon)
                .setContentTitle(title)
                .setContentText(compactText(body))
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setAutoCancel(false)
                .setShowWhen(true)
                .setOnlyAlertOnce(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setColor(Color.rgb(230, 208, 100))
                .setCategory(Notification.CATEGORY_STATUS);

        if (Build.VERSION.SDK_INT < 26) { builder.setSound(null); builder.setVibrate(new long[]{0}); }
        if (body.trim().length() > 0) builder.setStyle(new Notification.BigTextStyle().bigText(body));

        Notification notification = builder.build();
        notification.flags |= Notification.FLAG_ONGOING_EVENT;
        notification.flags |= Notification.FLAG_NO_CLEAR;

        if (Build.VERSION.SDK_INT >= 34) startForeground(STATUS_NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);
        else startForeground(STATUS_NOTIFICATION_ID, notification);
    }

    @Override public void onTaskRemoved(Intent rootIntent) { Watchdog.schedule(this); super.onTaskRemoved(rootIntent); }
    @Override public void onDestroy() { Watchdog.schedule(this); if (handler != null && ticker != null) handler.removeCallbacks(ticker); super.onDestroy(); }
    @Override public IBinder onBind(Intent intent) { return null; }
}
EOF
