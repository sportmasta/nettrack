# NetTrack — как пользоваться

Приёмка: [TEST_REPORT.md](TEST_REPORT.md) — **OK**. Код: [DEV.md](DEV.md).

Офлайн-разбор площадки: MikroTik `/export` и Cisco `show running-config`. Смысл — **поставить клиента** и **показать путь** на полной топологии.

## Топология (не «карта площадки»)

Четыре слоя сверху вниз:

1. **remote** — DirectCODD, CAFAP-R1, CAFAP-R2  
2. **edge** — MTK-WAN-R1  
3. **core** — N9K-A, N9K-B (между ними vPC)  
4. **access** — WS-C3850-A, WS-C3850-B  

Pan/zoom, Controls, MiniMap. Клик по узлу — одна схема LAN/WAN/VPN этого устройства.

### Линии

На проводе — только **номер** (1…N), цвет типа. Полный текст — в **каталоге под картой**, крупно, без zoom:

`1  C3850-A Po1 — N9K-A Po10`  
`7  N9K-A — N9K-B · vpc peer-link`  
`8  MTK Tun04 — DirectCODD Tun03`

Клик по номеру или строке подсвечивает линию. L3 `via …` не нумеруется — текст по наведению.

| Тип | На линии | В каталоге |
|---|---|---|
| L2 LACP | голубая цифра | `C3850-A Po1 — N9K-A Po10` |
| L2 vPC | жёлтая цифра | `N9K-A — N9K-B · vpc peer-link` |
| GRE Tun | фиолетовая цифра | `MTK Tun04 — DirectCODD Tun03` |
| L3 via | пунктир без номера | hover `via 10.255.63.254` |

Общие VLAN (SVI) на холсте **не** рисуются — это была сетка «все со всеми». Трейсер их по-прежнему видит в API.

## Направление трафика

В покое стрелок нет. После каждого **Показать путь** hops подсвечиваются жёлтыми стрелками; прошлый путь снимается. Остальные линии тускнеют.

Примеры (`WS-C3850-A`, VLAN504):

- `8.8.8.8` → C3850-A → N9K-A → MTK WAN  
- `10.38.0.40` → то же, затем GRE `Tun04` → DirectCODD  

## Импорт и таблица

**Добавить устройство** / **Новая схема** — `.rsc` / `.conf`. Справа: эмуляция клиента и таблица маршрутов.

## Запуск

```powershell
cd c:\Users\tankov\coding\nettrack
$env:DATABASE_URL="sqlite:///c:/Users/tankov/coding/nettrack/nettrack.db"
.\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --host 127.0.0.1 --port 8000
```

```powershell
cd c:\Users\tankov\coding\nettrack\frontend
npm run dev
```

http://localhost:5173 — после правок backend перезапустите uvicorn.

## Ограничения

Статический конфиг, без live RIB и ACL. Живые `nexus*.conf` / `catalyst*.conf` не коммитить.
