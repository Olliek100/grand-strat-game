# 19. The war goal window (DRAFT for the owner to mark up)

Written 2026-10-11, revised the same day after the owner supplied three CK3 "Declare War" screenshots (the Surrender, White Peace and Enforce Demands tabs). The owner asked for a screen where the player can assess their position before committing to a war goal, and back down if the target grows stronger. Layout only; nothing copied.

## What the CK3 screen does (structure to follow)
- A **side panel**, not a pop-up: it sits over the map, which stays visible and shows the district in question.
- **Header:** both rulers' portraits, an army and a gold figure for each, a **blue-versus-red strength bar** with a plain sentence under it ("their military strength is similar to ours"), and allies counted for each side.
- **War type row**, then **Choose an objective:** a list of the things the war can be fought for.
- **Three outcome tabs** (victory, white peace, defeat) that each show **what actually happens** in words and numbers ("you gain 100; you get X and its vassals"; "defender keeps the target titles"). This is the heart of the screen: you see the end state of every way it can go before you commit.
- **Footer:** the cost ("no cost") and one commit button, with a small settings gear.

## Owner's decisions (2026-10-11)
- **Opening the screen is free and commits nothing.** It is the information for the decision; only the commit button costs, and it says what.
- **One objective list.** "Acquire <district>" for each bordering district, plus "Subjugate <faction>" and "Vassalize <faction>", all in the same list (as in CK3's Choose an Objective). Picking a row changes the outcome tabs, the cost and the requirements.
- **No white peace tab for now.** A white peace is a settlement while fighting, a later piece. Backing off a claim before any war is a different act (*Back down*), kept separate; pressing a claim already costs opinion (the target's and onlookers'), so the screen shows that.
- **Verdict wording:** CK3's, a plain sentence under the strength bar (see below).

## Our window
It opens in the **left window slot** (doc 09: one at a time, about 560px, closed with Esc, X or right-click) so the map stays in view and the district is highlighted. Opened by the goal button in the faction card, which no longer commits at once.

**Before you commit**
1. **Header:** your leader and theirs, your side's strength against theirs as a bar, the sentence under it (their side is much weaker, weaker, similar, stronger or much stronger than yours, counting allies and backers), allies on each side (those who would be called), and each side's crew, arms and wealth.
2. **Objective list:** one list. Acquire each bordering district (garrison and what it pays beside it), then Subjugate and Vassalize the faction as rows of their own. The chosen row drives the tabs, costs and requirements below.
3. **Outcome tabs (two for now):** *If they give in or you win* (what you gain: the district, the tribute, the vassal) and *If you lose* (what they take, the war score they need, who's hurt). Same layout in both, gains in green and losses in red. A white peace tab joins when settling a war is built.
4. **Requirements list with ticks and crosses** (doc 09): border shared, cost affordable, cause (half price) or none, a treaty or truce you'd break (with the name cost), and whether the ultimatum could go early.
5. **Ultimatum window:** a bar from today to the latest day, with the 90-day notice marked. The chance they'd give in today and the ratio needed to go early sit beside it.
6. **Footer:** the cost on the commit button ("Begin justifying: 10 renown, 20 wealth"); *Not now* beside it. The bar and the verdict are the only live numbers.

**Once the claim is under way** (the same window, from the top-bar claim marker or the faction card)
- The sentence becomes a **trend**: the ratio when you began against now, and the change in their strength, in the same five words.
- Buttons: *Back down* (what you would lose, stated) and *Send ultimatum early* (shown with the reason it can't go yet: the ratio needed, and the days of notice left).
- When the wording drops a step (for example similar to stronger), a one-time alert says so and links here.

## Under the hood
- Already in the code: side strength and ratio, chance they'd give in, costs, days, cause, treaties broken, backers, allies who'd be called, what each goal does on acceptance (`_apply_war_goal`).
- New: the ratio at the start of the claim (stored in the claim, saved), a verdict function, a "who would be called on each side" list, the outcome text for each goal's three endings, and the worse-verdict alert. No rule changes.
- UI rules kept: how a system works stays in tooltips, no fact twice (the faction card's goal block shrinks to a one-line status plus an "Open claim" link), costs on the commit button.

## Verdict: what I suggest
CK3's approach, not a judgement: the bar plus one sentence in five steps, from the ratio of your side (with allies and backers) to theirs. Suggested cut-offs, tied to numbers the game already uses: **much weaker** (they are under 0.5x you), **weaker** (0.5 to 0.8), **similar** (0.8 to 1.25), **stronger** (1.25 to 2), **much stronger** (over 2). Hover gives the ratio and the factors. Beside it, two plain numbers that matter more than the word: **the chance they'd give in today** and **the ratio needed to send the ultimatum early** (1.5x for a claim). The "should I?" is left to the player.

## Built (2026-10-11)
The window is built as above: header, strength bar and sentence, one objective list, two outcome tabs, requirements, the ultimatum window, a footer that stays in view, the trend and the worse-verdict alert. Kept as lost for now: what you paid when you back down (revisit after a playtest). Still to come: a white peace tab, and opening this window from a claim against you.
