# FlowGate 🚀

[![Releases](https://img.shields.io/github/v/release/rock12/flowgate?label=Release&color=blue)](https://github.com/rock12/flowgate/releases)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-24.10%20%7C%2025.x-blue?logo=openwrt&logoColor=white)](https://openwrt.org/)
[![License](https://img.shields.io/badge/License-GPL--2.0-green.svg)](LICENSE)

**FlowGate** — мощный, надёжный и удобный инструмент умной маршрутизации и обхода сетевых блокировок для роутеров на базе **OpenWrt** (версии 24.10, 25.x и новее). 

Вся настройка осуществляется через красивый веб-интерфейс **LuCI**. Настроив роутер один раз, вы получаете свободный доступ к сервисам (YouTube, Discord, Instagram), онлайн-играм и стримингу на **всех** домашних устройствах (компьютеры, смартфоны, Smart TV, консоли) без необходимости устанавливать программы и VPN на каждое из них!

---

## 🌟 Почему FlowGate?

* 🛡️ **Интернет работает ВСЕГДА:** Даже если служба FlowGate выключена, перезагружается или удалена — ваш домашний интернет **не упадет** и продолжит работать штатно.
* ⚡ **Фикс Double NAT и MTU:** Автоматическая оптимизация MTU/MSS (`clamp-mss-to-pmtu`). Страницы больше не зависают, даже если роутер подключен через оптический GPON-терминал провайдера, мобильный 4G/5G модем или двойной NAT.
* 🎮 **Игровые списки правил (Gaming Rulesets):** Встроенная оптимизация маршрутизации для популярных игр (**Apex Legends, Call of Duty: Warzone, Fortnite, Battlefield, Warframe, Dark Souls, Ubisoft**, а также мега-список `ru-gaming-all`) для низкого пинга и обхода региональных блокировок.
* 🎬 **Прямой TorrServer и торренты (Direct):** Тяжёлый p2p/TorrServer трафик направляется напрямую без проксирования, не забивая туннель и не вызывая претензий у зарубежных хостинг-провайдеров.
* 📑 **Поддержка Clash YAML:** Автоматическое чтение и парсинг правил в формате Clash rule-provider напрямую в sing-box.
* 🚀 **UDPspeeder (speederv2):** Встроенная поддержка технологии Forward Error Correction (дублирование пакетов) для стабилизации UDP-трафика и устранения потерь пакетов в играх и голосовых чатах при нестабильном соединении.
* 🔒 **Защита от конфликтов и утечек:** Автоматическое отключение Hardware/Software Flow Offloading (конфликтующих с TProxy) и отключение IPv6 для исключения утечек трафика мимо туннеля.

---

## ⚡ Быстрая установка в 1 команду

### Шаг 1. Подключитесь к роутеру по SSH
* В **Windows 10/11**: нажмите `Win + X` ➔ выберите **Терминал** (или PowerShell).
* В **macOS / Linux**: откройте **Терминал**.
* Введите команду (замените `192.168.1.1` на IP вашего роутера, если меняли):
  ```sh
  ssh root@192.168.1.1
  ```
  *(при запросе введите пароль от роутера; при вводе символы пароля на экране не отображаются — это нормально).*

---

### Шаг 2. Запустите скрипт установки

Скопируйте и выполните одну команду:

**Основной источник (GitHub):**
```sh
sh <(wget -O - https://raw.githubusercontent.com/rock12/flowgate/main/install.sh)
```
*(или через curl: `sh <(curl -fsSL https://raw.githubusercontent.com/rock12/flowgate/main/install.sh)`)*

**🌐 Зеркало 1 (ghproxy.net — рекомендуется, если GitHub заблокирован или работает с задержками):**
```sh
sh <(wget -O - https://ghproxy.net/https://raw.githubusercontent.com/rock12/flowgate/main/install.sh)
```
*(или через curl: `sh <(curl -fsSL https://ghproxy.net/https://raw.githubusercontent.com/rock12/flowgate/main/install.sh)`)*

**🌐 Зеркало 2 (fastly.jsdelivr.net CDN):**
```sh
sh <(wget -O - https://fastly.jsdelivr.net/gh/rock12/flowgate@main/install.sh)
```
*(или через curl: `sh <(curl -fsSL https://fastly.jsdelivr.net/gh/rock12/flowgate@main/install.sh)`)*

#### Что сделает скрипт автоматически:
1. Определит архитектуру процессора роутера и версию OpenWrt (24.10 с `opkg` или 25.x с `apk`).
2. Установит все необходимые системные пакеты (`ucode`, `nftables`, `traceroute`, `iputils-ping`, утилиты `coreutils-sort`, `gzip`, `gawk`, `ipset`, `luci-compat` и модули ядра TProxy/TUN/Queue).
3. Скачает и установит бинарный файл `udpspeeder` (`speederv2`) с автовыбором зеркал.
4. Загрузит и установит актуальные пакеты FlowGate и русский интерфейс LuCI.
5. Отключит конфликтующий Flow Offloading и утечки IPv6.
6. Перезапустит веб-сервер и подготовит интерфейс к работе.

---

## 🗑️ Быстрое удаление FlowGate (в 1 команду)

Если вы решите удалить FlowGate, специальный мастер деинсталляции корректно остановит процессы, сбросит таблицы фаервола, вернет настройки DNS и восстановит сеть:

```sh
sh <(wget -O - https://raw.githubusercontent.com/rock12/flowgate/main/uninstall.sh)
```
*(зеркало: `sh <(wget -O - https://ghproxy.net/https://raw.githubusercontent.com/rock12/flowgate/main/uninstall.sh)`)*  
*(через curl: `sh <(curl -fsSL https://raw.githubusercontent.com/rock12/flowgate/main/uninstall.sh)`)*

> [!TIP]
> * **Сохранение настроек:** По умолчанию создается резервная копия конфига (`/etc/config/flowgate.bak`).
> * **Полное удаление под ноль:** Добавьте ключ `--purge` в конец команды, чтобы удалить все файлы и бэкапы:
>   ```sh
>   sh <(wget -O - https://raw.githubusercontent.com/rock12/flowgate/main/uninstall.sh) --purge
>   ```

---

## 🧭 Пошаговая настройка после установки (Гид для новичков)

После завершения установки откройте браузер и войдите в панель управления роутера (`http://192.168.1.1`).

### 1. Перейдите в раздел FlowGate
В верхнем меню роутера выберите:  
**Службы** (Services) ➔ **FlowGate**.

### 2. Добавьте сервер или подписку
* **Если у вас есть ссылка на подписку:**  
  Перейдите во вкладку **«Подписки»** ➔ нажмите **«Добавить»** ➔ вставьте ссылку (поддерживаются форматы V2Ray, Clash, sing-box JSON, Base64) ➔ нажмите **«Обновить подписки»**.
* **Если у вас отдельный ключ/конфиг:**  
  Перейдите во вкладку **«Узлы»** ➔ нажмите **«Добавить»** ➔ выберите протокол (**VLESS Reality**, **Hysteria 2**, **AmneziaWG**, **Shadowsocks** и др.) и введите параметры вашего сервера.

### 3. Выберите правила маршрутизации
Перейдите во вкладку **«Правила»**:
* Включите нужные вам списки блокировок: **YouTube**, **Discord**, **Instagram/Meta**, **Twitter**, **Copilot** и т.д.
* Для геймеров: выберите наборы правил для ваших игр (**Warzone**, **Apex Legends**, **Fortnite**, **Battlefield**, **Warframe**, **Dark Souls** или общий игровой список **ru-gaming-all**).
* Трафик для **TorrServer** и торрентов по умолчанию настроен в режим **Direct (Прямое подключение)** — вам ничего не нужно менять вручную!

### 4. Запустите сервис
* На главной странице **FlowGate** отметьте галочку **«Включено»**.
* Внизу страницы нажмите **«Сохранить и применить»**.
* Через 5–10 секунд статус сменится на **«Работает»**, и всё готово! 🎉

---

## 🎮 Поддерживаемые протоколы и технологии

| Категория | Поддерживаемые протоколы / Инструменты |
| :--- | :--- |
| **Прокси-протоколы** | **VLESS** (Reality, Vision), **Hysteria 2**, **xHTTP**, **AmneziaWG** (обфусцированный WireGuard + Warp), **Shadowsocks**, **TUIC**, **Mieru**, **WireGuard** |
| **Оптимизация игр** | **UDPspeeder** (дублирование UDP-пакетов / FEC), низколатентный TProxy |
| **Утилиты обхода DPI** | **Zapret** (`nfqws`), **Zapret2** (`nfqws2`), **ByeDPI** (`ciadpi`) |
| **Форматы правил** | **Clash YAML rule-provider**, sing-box rule-set (.srs / .json), доменные списки |
| **Подписки** | Base64, Clash YAML, sing-box JSON, V2Ray, Remnawave X-HWID |

---

## 🛠️ Ручная установка пакетов (для продвинутых)

Если вы хотите установить пакеты вручную, скачайте архивы со страницы [Releases](https://github.com/rock12/flowgate/releases) и выполните:

### Для OpenWrt с менеджером `apk` (OpenWrt 25.x / snapshot):
```sh
apk add --allow-untrusted flowgate_<версия>.apk
apk add --allow-untrusted luci-app-flowgate_<версия>.apk
apk add --allow-untrusted luci-i18n-flowgate-ru_<версия>.apk
```

### Для OpenWrt с менеджером `opkg` (OpenWrt 24.10):
```sh
opkg install --force-overwrite flowgate_<версия>.ipk
opkg install --force-overwrite luci-app-flowgate_<версия>.ipk
opkg install --force-overwrite luci-i18n-flowgate-ru_<версия>.ipk
```

После установки обновите кэш интерфейса:
```sh
rm -f /tmp/luci-indexcache* /var/luci-indexcache*
/etc/init.d/rpcd reload
```

---

## ❓ Часто задаваемые вопросы (FAQ)

<details>
<summary><b>1. Как проверить, что всё работает?</b></summary>

* Проверьте доступ к заблокированным ресурсам или откройте видео на YouTube в 4K.
* Перейдите во вкладку **FlowGate ➔ Обзор (Dashboard)** в LuCI: там отображается статус ядра, пинг узлов и активные соединения.
</details>

<details>
<summary><b>2. Не пропадет ли интернет, если сервер заблокируют?</b></summary>

Нет! Маршрутизация построена так, что весь трафик, не попадающий в списки блокировок, идёт напрямую через вашего провайдера. Если сервер станет недоступен, сайты из белых списков продолжат работать.
</details>

<details>
<summary><b>3. Как удалить FlowGate с роутера?</b></summary>

Воспользуйтесь командой быстрого удаления из раздела [Удаление FlowGate](#-быстрое-удаление-flowgate-в-1-команду):
```sh
sh <(wget -O - https://raw.githubusercontent.com/rock12/flowgate/main/uninstall.sh)
```
Скрипт аккуратно остановит службы, сбросит таблицы nftables, вернет стандартные настройки DNS dnsmasq и удалит пакеты. Если нужно удалить абсолютно всё без сохранения бэкапов конфигурации, добавьте ключ `--purge`.
</details>

---

## 📋 Системные требования

* **OpenWrt:** 24.10, 25.12 или новее.
* **Архитектура процессора:** Любая (`aarch64`, `arm`, `x86_64`, `mips_24kc` и др.).
* **Свободное место во Flash-памяти:** от 15–20 МБ (для роутеров с маленькой флеш-памятью рекомендуется extroot).

---

## ❤️ Благодарности (Credits & Acknowledgements)

Особая благодарность авторам и проектам, чей колоссальный труд послужил основой и источником вдохновения для FlowGate:
* **Forkop** ([@ushan0v](https://github.com/ushan0v)) — за превосходную оригинальную концепцию, архитектуру веб-интерфейса LuCI, модули умной маршрутизации и управления подписками.
* **Tachyon** ([@black-desk](https://github.com/black-desk)) — за ценные наработки, подходы к интеграции zapret2, архитектуру DNS-обработки и идеи разделения сервисов.
* **Zapret & Zapret2** ([@bol-van](https://github.com/bol-van)) — за легендарный автономный комплекс обхода DPI (`nfqws` и `nfqws2`).
* **sing-box** ([SagerNet](https://github.com/SagerNet/sing-box)) — за универсальное и максимально производительное ядро маршрутизации.
* **ByeDPI** ([@hufrea](https://github.com/hufrea)) — за легковесный инструмент обхода цензуры (`ciadpi`).
* **UDPspeeder** ([@wangyu-](https://github.com/wangyu-/UDPspeeder)) — за технологию FEC для устранения потерь пакетов и лагов в играх и голосовых звонках.

---

## 📄 Лицензия

Проект распространяется под свободной лицензией **GPL-2.0-or-later**.
