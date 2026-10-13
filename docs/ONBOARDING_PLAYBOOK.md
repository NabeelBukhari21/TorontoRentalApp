# Purrperty: Onboarding and Paywall Playbook

> **Core rule:** users don't care how many screens there are. They care
> how fast they reach value. Every screen should either move them closer
> to the "aha" moment or make the app feel more like theirs.

---

## 1. The shape of the flow

**Hook → Personalise → Sign up → Aha → Habit**

1. **Hook.** Purr says hi (the animated clip) and sells the *outcome*, not a
   list of features.
   - Write "Never chase rent again" or "Repairs sorted while you sleep".
   - Don't write "Rent tracking, maintenance module…".
2. **Personalise.** A short conversational quiz with Purr: who you are,
   what you manage, what's painful, what you want.
3. **Sign up.** By now they're invested, so the sign-up screen reads as a
   pitch, not a form.
4. **Aha.** Add your first property and first tenant, and see it come
   alive on Home.
5. **Habit.** Ask for notifications at the right moment, then give daily
   value: rent status, repair updates, Purr's brief.

### Recommended Purrperty flow

| # | Screen | Purpose | Purr's role |
|---|--------|---------|-------------|
| 1 | Splash | The logo builds itself | Hops in and cheers |
| 2 | Hello | One outcome-led promise | Hello clip |
| 3 | Quiz: "Who are you?" | Landlord, property manager or tenant | Thinking |
| 4 | Quiz: "How many units?" | 1, 2–5, 6–20, 20+ | Reacts to the answer |
| 5 | Quiz: "What's your biggest headache?" | Multi-select: late rent, repairs, tenant messages, paperwork, finding tenants | Sympathetic face |
| 6 | Quiz: "What's your goal?" | Save time, get paid on time, fewer vacancies | Excited |
| 7 | Make it yours | Theme or accent colour, Home layout, light or dark | Shows off the choice |
| 8 | "Building your Purrperty…" | Animated loading screen (see §4) | Working at the laptop |
| 9 | "Here's what you unlocked" | The quiz answers become features they now have | Cheering |
| 10 | Sign up | Pitch: social proof, outcome, password checks | Small, encouraging |
| 11 | Add first property | Address, units, photo. Fast, one field per step | Guides each field |
| 12 | Aha celebration | Confetti, then the founder's note or video | Leaps |
| 13 | Notification priming | Preview of a real notification, then the system prompt | Holds the "phone" |
| 14 | Trial and paywall | 3-step trial flow (see §6) | Calm, honest |
| 15 | Home | Already filled in from the answers | Daily brief |

> **Engineering note:** a quiz that runs before sign-up means the answers
> must live locally (an `OnboardingProfile` saved on the device). They are
> attached to the account at sign-up, then shape Home, the tips and the
> paywall.

---

## 2. Personalisation that pays off

- **Conversational quiz.** Purr asks, the user taps. One question per
  screen with big, colourful choice cards. Allow several answers for
  "headaches" (multi-intent).
- **Make it feel like theirs before they start.** Offer an accent colour,
  light or dark mode, and Home layout (cards or compact). Later this could
  include a map view or an illustration style for their building.
- **Show what the answers unlocked.** For example: *"You picked late rent
  → Rent reminders are on. You manage 6 units → Your portfolio dashboard
  is ready."* They see the value before they've used anything.
- **State the outcome in numbers they can picture.** For example, *"Based
  on 6 units, Purrperty can save you about 4 hours a month."* Only use
  numbers we can defend, and label them as estimates.
- **Home is already populated.** Purr's brief, the widgets they care about
  and a "Next step" card ("Add your first tenant") arrive filled in, never
  as an empty state.
- **Tailored pricing.** The quiz answers choose the recommended plan. A
  1-unit landlord isn't shown the 50-unit tier first.

---

## 3. Moments of delight

- **The founder's touch at the aha moment.** After the first property is
  added, show a short, warm founder video or a handwritten-style note with
  a signature (Airbnb-style).
- **A personal note after sign-up.** A short note from the founder, not a
  marketing email.
- **Turn the boring screens into a pitch.** The sign-up screen gets social
  proof (reviews, "Trusted by X Toronto landlords") and a single clear
  outcome. Use real numbers only.
- **A live password checklist.** Each requirement ticks with an animated
  checkmark and a light haptic as it's met.
- **Celebrate milestones.** Examples: first rent collected, first repair
  closed, one year on Purrperty, full occupancy.
  - Birthdays are optional. Asking for a date of birth just for a
    celebration adds privacy risk to a landlord app, so prefer
    account-anniversary moments.
- **Name or style the mascot.** Purr is already named. The equivalent
  "virtual pet" moment is choosing Purr's accessory or the app's accent
  colour.

---

## 4. Motion, loading and success states

- **Something is always happening.** Every wait gets a unique, animated
  treatment: Purr typing, homes building, checkmarks landing.
- **Polish the screens nobody bothers with:** email verification,
  password rules, permission prompts and saving.
- **Make success screens the reward.** Use confetti, haptics, Purr
  leaping and a clear "what's next".
- **Use the labour illusion honestly.** For trust-sensitive steps (identity
  checks, screening, importing a portfolio), show the real steps as they
  happen, for example:
  - ✓ Checking address
  - ✓ Setting up units
  - ✓ Preparing your dashboard

  A deliberate pause of about 1.5–3 seconds builds trust. Never fake work
  that isn't happening, and never slow down tasks users repeat daily.

---

## 5. Psychology (used ethically)

- **Goal-gradient effect.** People speed up near a finish line. Show
  concrete progress such as "Step 3 of 5", "1 minute left" or "2 of 4
  setup tasks done". Make the first step feel already started, for
  example with a progress bar that begins at about 10%.
- **Von Restorff (isolation) effect.** Whatever looks different gets
  noticed and remembered. Use one primary call-to-action per screen with a
  distinct colour, and accent icons for key features. Never present a wall
  of identical options; that also reduces cognitive load.
- **Endowed progress and investment.** Every answer the user gives makes
  the app more "theirs" and makes them more likely to finish. This is why
  well-placed effort (the quiz, personalisation) can *increase*
  conversion. The effort has to feel meaningful. Friction at payment or
  sign-in always hurts.
- **Micro-wins.** Small, celebrated completions (first property, first
  tenant) build momentum toward the habit.

---

## 6. Paywall

### Principles
- **A paywall is a flow, not a screen.** Shown at the wrong moment it's a
  wall. Shown right after the aha moment, it's a natural next step.
- **Sell outcomes, not features.** Make the value obvious. A short video
  or animation of the app working converts better than a list.
- **Reducing risk beats persuasion.** Explain the trial clearly: no charge
  today, a reminder before it ends, and how to cancel in two taps. Clear
  trials also reduce refunds and bad reviews.
- **Make it fun.** Use animation, haptics and Purr, but keep the prices
  and terms crystal clear.

### Where paywalls appear
1. At the end of onboarding, after the aha moment.
2. When the user taps a premium feature (contextual upgrade).
3. Under Settings → Plan.
4. As a win-back or exit offer when they decline: a longer trial or a
   monthly plan instead of yearly.

### The 3-step trial flow
1. **"Try Purrperty Premium free for 14 days"**, with the outcomes they
   chose in the quiz.
2. **"How your free trial works"** as a timeline:
   - Today: full access.
   - Day 12: we remind you.
   - Day 14: the trial ends.

   Offer a reminder notification here.
3. **Plan choice**, defaulting to yearly with the 14-day trial.

### Pricing and packaging
- Show only **two options side by side: Yearly (pre-selected) and
  Monthly.** Hide other tiers behind "View all plans" so the base paywall
  stays simple.
- **Discount badge** on yearly, for example "Save 40%", using the real
  calculated saving.
- **Price anchoring:**
  - Break the price down into a monthly or weekly figure, presented
    visually.
  - Compare it to costs a landlord already pays. The strongest anchor is a
    property manager's fee, which is often a percentage of monthly rent
    (verify current Ontario rates before quoting). Other options: one late
    payment, one missed repair, "less than a coffee a week".
- Show **every benefit for every tier**; people like to read before
  paying.
- Yearly isn't always the right default. Test monthly against yearly
  before deciding.

### Soft vs. hard paywall
- **Default to a soft paywall** with a visible close button.
- **Consider a hard paywall only when:**
  - users come from paid ads, or
  - there are plenty of downloads but almost no sales.
- **By acquisition source:** the "Where did you hear about us?" answer can
  decide whether the close button is shown. Show it to App Store
  discoverers; consider a harder paywall for paid-social traffic.
  - Self-reported answers are noisy. Prefer real attribution data when it
    becomes available.
- **App Store compliance (non-negotiable):**
  - State the price, billing period, trial length and auto-renewal clearly.
  - Include working Restore Purchases, Terms and Privacy links.
  - Don't hide or disguise the close button.
  - Don't make the trial look free forever.

  Apple rejects paywalls that do these things, and they damage reviews.

---

## 7. Permissions at the right moment

- **Notifications:** ask straight after the aha moment, not on first
  launch. First show an animated priming screen with a preview of a real
  notification ("Rent received from Unit 2 ✅"). Only call the system
  prompt if they tap "Turn on".
- The same pattern applies to photos (property pictures) and location
  (map view). Ask only when the feature is first used.

---

## 8. What to measure

- **Time to value:** minutes from first launch to the first property
  added.
- **Funnel completion:** the drop-off at every onboarding step.
- **Activation:** the percentage of sign-ups who add a property *and* a
  tenant in their first session.
- **Notification opt-in rate** after priming.
- **Trial start rate, trial-to-paid conversion and refund rate.**
- **Day-1, day-7 and day-30 retention.**

All events go through the existing consent-gated `AnalyticsService`.

---

## 9. Takeaways
- Faster value beats fewer screens.
- Onboarding should not feel like onboarding. Use personalisation,
  micro-wins, outcomes and constant motion.
- Earn the paywall, explain the trial honestly, and keep it simple.
