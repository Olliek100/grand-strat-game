# Houses and Marriage

Spine stage **C3-C4** (08-spine.md): doc 14's marriage slices and the **vassal houses** agreed on 2026-10-02 (doc 15, decision log). Written 2026-10-09. **Status: built (H1-H3, v1.42) with the recommended answers to the questions below; the owner said "build it" without answering them, so they stand until changed.**

## Why
The agreed spine sentence: *"Over generations, marriages, children and what you teach them turn your crew into a dynasty, and the gangs around you into the great houses of a rebuilt city."* Today that can't happen:
- **Only the leader ever marries** (a spouse is made when they take power or are widowed). Grown children never marry, so there are no grandchildren: a family thins out over a run instead of branching.
- **Vassalize brings a ruling family with nowhere to sit:** they join as ordinary members with lowered loyalty (doc 15's stopgap).
- **There's no "house" anywhere:** one dynasty per faction, and everyone else is a captain.

## What exists to build on
- **Choice events** (doc 14 slice 1): decisions about people, options cost nothing, timed effects; the AI answers its own.
- **Births for every married couple**, children educated from 6, traits settling at 16 (doc 14 slices 1-2).
- **Loyalty** per character with reasons (council.json "loyalty"), desertion below 20, and **civil war** when a succession is contested (a faction splits on the map).
- **Tributaries** and **Vassalize** (doc 15).

---

## Part 1. Marriage within the faction
- **When:** a family member who's grown (16+) and unmarried gets a choice event, **"A Match for {name}"**, around 18 (then every couple of years until married, or not).
- **The options** (each costs nothing, per the owner's rule; each is a different bet):
  - **A captain or councillor** (the best unmarried one is named): binds them to the family (their loyalty +15, lasting) and the children lean toward their best skill and nature.
  - **Someone from the people:** steadier districts for a while (grievance falls faster), and the children lean Of the People.
  - **A house** (once houses exist, Part 2): binds that house (its loyalty +20) and the children are family to both.
  - **Not yet:** asked again in two years.
- **The spouse joins the family;** their children are family (heirs, students, matches in their turn). Grandchildren follow.
- **The AI answers the same event** by its leanings.
- **Guardrail:** families can't swell without limit. Today it's 4 children per couple; add a cap on living family members per faction (about 16), beyond which younger children "leave to make their own way" (a captain elsewhere) or, once houses exist, can found one.

**Done when:** in a 10-year simulated game the player's family has living grandchildren; the family stays between 6 and 16; speed holds.

## Part 2. Houses
A **house** is a family inside a faction that isn't the ruling one, with land of its own. The owner's decisions (2026-10-02): it **holds its old districts**, has **loyalty that can turn into revolt**, **marries into your family**, and **marries other factions' houses**.

- **Where houses come from:**
  1. **Vassalize:** the absorbed ruling family becomes a house holding the districts it had.
  2. **Granting land** (proposed): name a grown child of your family, or a loyal captain, lord of one of your districts; they found a **cadet house**. A home for spare children and rivals to the heir, at a price (below).
- **What a house's district is:** still yours on the map (your colour, your land), but the house **keeps a share of its income** (proposed 25%), and its loyalty shifts with how you treat it.
- **House loyalty** = its head's loyalty, with house reasons: kept its land (+), lost land in your wars (-), a match with your family (+), passed over for the council (-), your leader's nature (as today). Shown on the house's card and on its districts.
- **Revolt:** a house whose loyalty stays below 20 for a while warns you ("restless"), then may **break away with its districts** as a faction of its own, at war with you (the same split as a civil war). Telegraphed, never sudden.
- **Call to arms:** at war, you can ask a house to fight (its people join your assaults: its districts' garrisons and manpower count with yours). It may decline; joining earns it loyalty and a share of what's taken.
- **Succession:** a house head can contest your succession like a councillor (claim from its land and blood), which is how a run's great houses come to matter.

**Done when:** in a 10-year simulated game at least one house exists in most factions and matters (a revolt seen coming, a house joining a war, or a match made with it); a disloyal house can always be seen coming before it revolts.

## Part 3. Marriage between factions (the old S5)
- **A diplomatic offer, "Propose a match":** one of your family (or a house's) to one of theirs (or their houses'). Scored like treaties: opinion, renown, both sides' interests.
- **The family tie it creates:** opinion between the factions (+20, lasting while both spouses live), better odds for pacts, alliances and backing a claim, and a reason not to press claims on each other.
- **Claims through blood** (proposed for later): a grandchild with blood in another faction's ruling line can claim it when that line fails. It's the peaceful route to power in the 07 design, and the reason a claim could cite "they hold land you held".

**Done when:** a marriage is worth weighing against a war: in simulation, families tied by marriage fight each other clearly less often.

---

## Build order (proposed)
1. **H1, matches within the faction** (Part 1, without the house option): grown children marry; grandchildren; the family cap. The smallest step that makes "generations" real.
2. **H2, houses** (Part 2): Vassalize makes a house; granted land; house loyalty, revolt, call to arms; matches with houses.
3. **H3, marriage between factions** (Part 3, without blood claims).
4. Later: blood claims; gatherings (doc 14 slice 5: weddings, wakes).

Each is one build: tests, a simulation pass, screenshots, then play.

## Needs a decision-log entry before building
1. **Grown family members marry through a choice event** (Part 1), and a cap keeps families from swelling.
2. **Houses** as defined in Part 2 (the owner's four points are logged; the rest here isn't).
3. **Revolt of a house** reuses the civil-war split.

## Questions for the owner
1. **Matches:** a choice event for each grown family member (you pick, as with upbringing), or automatic with a notice? *Recommended: the choice event; it's the slice-1 pattern and it's where the dynasty is shaped.*
2. **A house's districts:** stay fully yours to act in, with the house keeping a share of their income (proposed), or does the house run them (you can't act there, like a tributary inside your borders)?
3. **Granting land to found a cadet house:** yes or no? *Recommended yes: it gives spare children and ambitious captains somewhere to go, and makes houses come from your own choices, not only from conquest.*
4. **A house that revolts:** a full new faction at war with you (the civil-war split), or only those districts going independent?
5. **Claims through blood** (Part 3): now with H3, or later?

## Built (v1.42, 2026-10-09)
- **H1-H3 as above**, with the recommended answers: matches are a choice event; a house's districts stay yours and the house keeps 25% of their income; granting land founds a cadet house (a grown family member, or a captain with loyalty 50+; never your home, and you keep one district for yourself); a revolting house becomes a faction at war with you (the civil-war split); claims through blood later.
- **Differences:** the family cap stops new pregnancies rather than sending children away; a house's own children aren't ruling family (no upbringing or match events for them yet); the AI founds one cadet house per five districts; the call to arms can be asked every 180 days.
- **What simulation showed:** houses now exist and matter in most games, and consolidation fell (3-6 factions left at year four). Marriages and grandchildren happen, but grown children are scarce: they die leading ventures, and conquest wipes whole families. That, and long-run revolts, need a longer look in play.
