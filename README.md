# YuriEA (MT5)

**YuriEA** is a rule-based MetaTrader 5 Expert Advisor designed to execute **price-validated trades only after confirmation**, not on raw indicator signals.

This EA is built to mirror **professional discretionary trade validation**, with strict post-signal logic, structure acceptance, and invalidation rules — eliminating late, weak, and choppy entries.

---

## ❗ Core Philosophy

> **Signal ≠ Entry**

Indicators may generate signals.  
**Price action decides whether a trade is allowed.**

YuriEA enforces this separation in code.

---

## 🚫 What YuriEA Does NOT Do

- ❌ Does NOT predict markets  
- ❌ Does NOT trade on the signal candle  
- ❌ Does NOT use EMA, RSI, MACD, or indicator crosses for entry decisions  
- ❌ Does NOT assume intra-bar behavior  
- ❌ Does NOT auto-reverse after failed setups  
- ❌ Does NOT chase price or trade inside chop  

---

## ✅ What YuriEA DOES Do

- Uses **signals only as alerts**
- Enters a **WAIT state** after a signal
- Validates trades using **closed-candle price action**
- Requires **acceptance beyond structure**
- Enforces **hold / no-reclaim rules**
- Invalidates **late signals after impulses**
- Applies **stricter timing on lower timeframes**
- Maintains **directional integrity** (BUY ≠ SELL)

---

## 🧠 Trade Validation Framework

All logic follows this fixed order:

1. **Signal detected**
   - BUY or SELL signal only triggers monitoring
   - No trade is allowed here

2. **Signal candle is locked**
   - Signal candle is never tradable

3. **Post-signal candle strength**
   - ≥ ~60% body
   - Close near candle extreme
   - No dominant opposing wick
   - Weak or indecisive candles invalidate the setup

4. **Acceptance (mandatory)**
   - BUY: candle **closes above structure**
   - SELL: candle **closes below structure**
   - Body close only (wicks ignored)
   - Expansion required

5. **Hold / No reclaim**
   - Price must hold beyond the level
   - Immediate reclaim invalidates the setup

6. **Timing rules**
   - M1–M5: must move in favor within **1–3 candles**
   - M15+: brief pause allowed, but follow-through required

If any step fails → **NO TRADE**

---

## ⛔ Automatic Invalidation

A setup is canceled if:

- Signal appears **after a strong impulse** (late signal)
- No cooldown candle exists after impulse
- Price chops or overlaps after the signal
- Acceptance never occurs
- Strong opposite candle appears during validation
- Hold fails (reclaim)

Failed setups do **not** authorize reversal trades.

---

## 📌 Entry Rules

A trade is executed only:

- At the **next candle open after acceptance holds** (default), or
- Optionally at acceptance close (configurable)

Never:
- On the signal candle
- Inside chop
- After a reclaim

---

## ⚙️ Key Features

- Post-signal validation engine (PSV)
- Binary GO / NO GO logic
- Timeframe-aware strictness
- Late-signal binary invalidation
- Optional retest logic (disabled by default)
- Clean state resets (no ghost trades)

---

## 🧪 Intended Use

- Forward testing
- Rule validation
- Bridging discretionary logic into automation
- Preventing emotional or impulsive entries

This EA is **logic-first**, not indicator-first.

---

## ⚠️ Disclaimer

YuriEA is a **trade execution and validation tool**, not a prediction system.  
Trading involves risk. Use on demo or small risk while testing.

---

## 📄 License

Use, modify, and test freely.  
Redistribution or commercial use is at your own discretion.

---

## 🧩 Final Note

If your chart logic and EA behavior ever disagree —  
**the EA is wrong and must be fixed.**

That principle is enforced in this project.
