# How Predictable You Are — Canonical Story, Boss Progression & Endings

## 1. Premise & The Metal Wizard's Siege
A Wizard obsessed with the element of **Metal** studied human behavior and forged a predictive Markov automaton—the **Guardian Robot**—capable of learning human patterns and conjuring **Fire**, **Water**, and **Wood**. Ambushing the royal garden, the automaton defeated the three guardian mages and kidnapped **Princess Aria** into the Metal Wizard's volcanic iron fortress.

With the neighboring realms under threat and a **40-Week** conquest horizon ticking down, **King Aldric** turns to the **Sacred Temple** and summons a young **Cleric** capable of wielding all elements to rescue the Princess and shatter Master Hand's predictive algorithms.

---

## 2. Timeline Branching: Week 0 vs. Post-Week 0 (`Week 1+`)

### Path A — The Week 0 Miracle (`currentWeek == 0`)
- On **Week 0**, the Metal Wizard has not yet completed his backup constructs or planted the dark mechanical seal inside the Princess.
- If the Cleric defeats both the **Guardian Robot (`100 HP`)** and the **Metal Wizard (`300 HP`)** during **Week 0** without retreating to the World Map, the Princess is rescued completely untouched, immediately unlocking **Ending 1: Flawless Rescue (Secret)**.

### Path B — The Piercing Scream & The Dark Seal (`currentWeek >= 1`)
- If the Cleric returns from the Metal Wizard's Lair after Week 0 without defeating both the Guardian Robot and the Metal Wizard, a piercing scream echoes from the dungeon (inspected via the **Watch Tower** spyglass).
- From **Week 10** onward, the Metal Wizard also deploys the **Robot Archmage (`200 HP`)** between the Guardian Robot and himself.
- Whenever the Cleric defeats the **Metal Wizard (`300 HP`)** at **Week 1 or later (`currentWeek >= 1`)**, the Cleric rescues the unconscious Princess and carries her back to the **Sacred Temple** so the **Temple High Master**—who never leaves the sanctuary due to his sacred vows—can heal her.

---

## 3. Confrontation at the Sacred Temple & Moral Choice
Inside the **Sacred Temple** (`temple_arena_bg`), while channeling a healing prayer over the Princess, the **Temple High Master** senses a dark mechanical anomaly sealed inside her by the Metal Wizard. He warns the young Cleric that if the anomaly awakens, it will raze the capital, and insists that the Princess must be sacrificed upon the altar immediately.

The Cleric faces two choices:
1. **`"Sacrifice the Princess"` (Accept Sacrifice):**
   - The Cleric steps aside and allows the High Master to complete the rite of containment.
   - The run ends immediately (skipping the Temple High Master and Baby Mage Robot fights) and unlocks **Ending 3: The Sacred Sacrifice**.
2. **`"Refuse & Protect Her"` (Defy the Master):**
   - The Cleric refuses to let the Princess die.
   - Bound by his vows to protect the kingdom at any cost, the **Temple High Master (`350 HP`)** raises his golden staff and initiates a mandatory duel against the Cleric inside the Sacred Temple.

---

## 4. Boss Progression & Mathematical AI Models

| Stage | Boss Name | HP | Arena | Elemental Pool | Mathematical AI / Combat Mechanic |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Stage 1** | **Guardian Robot** | `100 HP` | Dark Forge (`forge_arena_bg`) | 3 Base Elements (`Fire`, `Water`, `Wood`) | **Cumulative Markov Matrix:** Tracks all historical 1-step player transitions and counters the player's most frequent follow-up. |
| **Stage 2** | **Robot Archmage** *(Week 10+)* | `200 HP` | Dark Forge (`forge_arena_bg`) | All 5 Elements (`Fire`, `Water`, `Wood`, `Earth`, `Metal`) | **1-Step Short-Term Memory:** Ignores cumulative history and counters only the player's single most recent transition out of each element (exposed via the **Markov Recalibrator**). |
| **Stage 3** | **Metal Wizard** | `300 HP` | Dark Forge (`forge_arena_bg`) | Pure `Metal` (`100%`) | **Pure Metal Obsession:** Bypasses the Markov matrix and conjures exclusively `Metal` on every turn. |
| **Stage 5** | **Temple High Master** *(Week 1+ Sanctuary)* | `350 HP` | Sacred Temple (`temple_arena_bg`) | All 5 Elements (`Fire`, `Water`, `Wood`, `Earth`, `Metal`) | **Pure Divine Chaos (`1/5` Uniform Random):** Ignores all transition history and channels all 5 elements with 100% pure uniform randomness (`1/5` probability per element). |
| **Stage 4** | **Baby Mage Robot** *(Final Boss)* | `400 HP` | Sacred Temple (`temple_arena_bg`) | Dual Harmonic Spells (All 5 Elements in pairs) | **Deterministic $\pi$ Sequence (`3.1415926535...`) & Dual Combined Spells:** Casts **2 harmonic elements simultaneously** every turn driven by the digits of $\pi$. |

### Sanctuary Altar Restoration (Between Temple High Master & Baby Mage Robot)
When the Cleric reduces the **Temple High Master's HP to `0`**, the Sacred Temple's altar restores the Cleric's **HP and Mana Pool back to 100%** (`playerMaxHp` and `playerMaxMana`) right as the dark seal inside the Princess shatters and awakens as the **Baby Mage Robot (`400 HP`)**.

---

## 5. Final Boss Mechanics: Baby Mage Robot (`400 HP`, Dual Combined Magic & $\pi$ Core)

### Deterministic $\pi$ (`3.1415926535...`) Sequence AI
On each turn of the Baby Mage Robot battle, the construct advances 1 digit along the digits of $\pi$ (`3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3, 2, 3, 8, 4, 6...`) and conjures one of **5 harmonic dual-element pairs** that each share **one unique common weakness**:

| $\pi$ Digit | Dual Harmonic Spells Cast | Unique Common Weakness (Beats Both) | Safe 3-Element Counter (Beats 1 & Ties 1) |
| :---: | :--- | :--- | :--- |
| **`0` or `1`** | **`Fire + Water`** | **`Earth`** | `Water` *(beats Fire, ties Water)* |
| **`2` or `3`** | **`Water + Earth`** | **`Wood`** | `Wood` *(beats both Water & Earth)* |
| **`4` or `5`** | **`Earth + Wood`** | **`Metal`** | `Wood` *(beats Earth, ties Wood)* |
| **`6` or `7`** | **`Wood + Metal`** | **`Fire`** | `Fire` *(beats both Wood & Metal)* |
| **`8` or `9`** | **`Metal + Fire`** | **`Water`** | `Water` *(beats both Metal & Fire)* |

### Dual-Spell Combat Resolution Rules (`1` Mana Consumed per Turn)
The Cleric's chosen element is evaluated independently against **Spell A** and **Spell B** using the 5-element Wu Xing interactions:
- **Beats BOTH spells** (unique common weakness): Deals **`1 HP` damage** to Baby Mage Robot (`-1 HP` boss, `0 HP` player) and grants **`+1` Orb of EACH of the two defeated elements** (`+2` Orbs total, or `+4` with Blessing of Harvest).
- **Beats 1 spell & Ties 1 spell**: Deals **`1 HP` damage** to Baby Mage Robot (`-1 HP` boss, `0 HP` player) and grants **`+1` Orb of the defeated element**.
- **Beats 1 spell & Loses to 1 spell** (Simultaneous Harmonic Clash): Deals **`1 HP` damage to Baby Mage Robot AND `1 HP` damage to the Cleric** (`-1 HP` boss, `-1 HP` player) and grants **`+1` Orb of the defeated element**.
- **Ties 1 spell & Loses to 1 spell**: Deals **`1 HP` damage** to the Cleric (`0 HP` boss, `-1 HP` player).
- **Loses to BOTH spells** (Twin Overload / Double Damage): Deals **`2 HP` damage** to the Cleric (`0 HP` boss, `-2 HP` player).

---

## 6. The 6 Canonical Endings (`X / 6` in the Royal Library)

1. **Flawless Rescue (Secret):**
   - *Trigger:* Defeat both the **Guardian Robot (`100 HP`)** and the **Metal Wizard (`300 HP`)** while still on **`Week 0`**.
2. **Sanctuary Victory (Standard):**
   - *Trigger:* Defeat the **Metal Wizard** at `Week 1+`, choose **`"Refuse & Protect Her"`**, defeat the **Temple High Master (`350 HP`)**, and defeat the **Baby Mage Robot (`400 HP`)** inside the Sacred Temple.
3. **The Sacred Sacrifice:**
   - *Trigger:* Choose **`"Sacrifice the Princess"`** at the Sacred Temple moral choice, fall to `0 HP` against the **Temple High Master**, or confirm **Teleport** (fleeing the sanctuary) during the Temple High Master duel.
4. **The Deserter:**
   - *Trigger:* Confirm **Teleport** to flee the Sacred Temple in terror during the final battle against the **Baby Mage Robot (`400 HP`)**, leaving the construct free to destroy the kingdom.
5. **Ruin:**
   - *Trigger:* Fall to **`0 HP`** against the Metal Wizard's Lair constructs (`Guardian Robot`, `Robot Archmage`, `Metal Wizard`) or the awakened `Baby Mage Robot` and accept death.
6. **Invasion (Time Out):**
   - *Trigger:* Exceed **`Week 40`** (entering `Week 41` siege) without saving the kingdom.
