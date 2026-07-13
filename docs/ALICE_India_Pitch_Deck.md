# ALICE — India Pitch Deck
**Private AI Companion for India's Knowledge Economy**

**Tagline:** *Your always-on AI that lives on your desktop — not in a browser tab.*

---

## Slide 1: Title
**ALICE**  
**Private. Contextual. Always with you.**

A macOS menu-bar AI companion that sees your screen, hears your voice, and guides you — all while keeping your data private.

**For Indian professionals, researchers, bureaucrats, creators & founders.**

**v1.0 live** • macOS DMG ready • MIT licensed • Built in India

[Logo: Futuristic glowing orb with luminous "A" — purple-to-electric-blue gradient, subtle circuit pattern]

---

## Slide 2: The Problem
**India's knowledge workers are drowning in fragmented AI**

- 50M+ professionals switch between ChatGPT, Claude, Gemini, Notion AI, etc.
- **Privacy nightmare**: Every prompt goes to US servers. DPDP Act compliance is a ticking bomb for enterprises & government.
- **Context loss**: Copy-paste screenshots, lose thread, repeat yourself.
- **Voice is broken**: Most tools are text-first. Hindi + Indian English accents still fail.
- **No spatial intelligence**: AI tells you "click the blue button" instead of *pointing at it*.
- Result: Lost hours every week. High-value users (IIT researchers, lawyers, IAS officers, startup founders) are the most frustrated.

**Current AI tools were not built for India.**

---

## Slide 3: The Opportunity
**India is building its AI sovereignty moment**

- **IndiaAI Mission**: ₹10,000 Cr committed.
- Government mandates data localization + "AI for All".
- Mac + professional desktop use exploding in metros + Tier-2 cities.
- 10M+ macOS users in India (fastest growing segment among knowledge workers).
- DPDP Act + rising distrust of foreign clouds = massive demand for **private, on-device-first** tools.
- Global trend toward "ambient AI companions" (but no one owns the desktop layer in India yet).

**Whoever owns the private desktop AI layer in India wins the next decade.**

---

## Slide 4: Solution — ALICE
**The floating AI orb that lives next to your cursor**

- Menu-bar only (no dock icon, zero distraction)
- **Orb follows your cursor** across all monitors
- **Push-to-talk voice** (Ctrl+Option) — works with Indian accents
- **Sees your entire screen** (ScreenCaptureKit, multi-monitor)
- **Talks back** with natural ElevenLabs voice
- **Points at UI elements** — literally flies to buttons, fields, menus and highlights them
- Pluggable STT (AssemblyAI + local Apple fallback)
- Claude Sonnet/Opus + OpenAI (via secure gateway)
- **Zero API keys in the app** — everything routes through sovereign Cloudflare Worker

**ALICE doesn't replace your tools. It makes you 10x better at using them.**

---

## Slide 5: How ALICE Works (User Flow)
1. Hold **Ctrl + Option** → Orb appears
2. Speak naturally (English / Hindi mix OK)
3. ALICE captures active screen(s) + your voice
4. Sends to gateway → Claude/OpenAI (with vision)
5. Streams response + speaks it
6. Parses [POINT:x,y:label] → Orb flies + pulses on the exact UI element

**Example:**
"Find the export button and tell me how to change the format."

→ ALICE highlights the exact button, explains, and can even guide step-by-step.

---

## Slide 6: Why ALICE Wins for India
| Feature              | ChatGPT/Claude Apps | ALICE (India-first)          |
|----------------------|---------------------|------------------------------|
| Privacy (DPDP)       | ❌ Cloud by default | ✅ Keys on gateway, local fallback |
| Cursor context       | ❌ None             | ✅ Orb + element pointing      |
| Voice (Indian accent)| ❌ Weak             | ✅ Pluggable + local fallback  |
| Multi-monitor        | ❌ No               | ✅ Full support                |
| Desktop integration  | ❌ Browser/tab      | ✅ Menu-bar native             |
| Data sovereignty     | ❌ US servers       | ✅ Can host gateway in India   |
| Cost for students    | Pay per use         | Freemium + local models        |

**Built as clean-room MIT project. No foreign IP baggage.**

---

## Slide 7: Market Size
**TAM (India + Global)**

- **India knowledge workers**: 50M+ (2026) → 100M+ by 2030
- **Mac + high-end laptop users** (primary target): 10M+ in India, growing 25% YoY
- **Served markets**: Researchers, lawyers, bureaucrats, product managers, designers, startup founders, MSME consultants
- **Expansion**: Windows port (2026), on-device models (Gemma/Llama quantized for India), mobile companion

**Serviceable Obtainable Market (Year 2)**: 500K paying users @ ₹999–4,999/year + enterprise/government contracts.

**Bottom line**: A ₹500 Cr+ ARR company is realistic if we own the private desktop AI layer.

---

## Slide 8: Business Model
**Freemium + Sovereign Premium**

- **Free**: Local Apple Speech + small on-device models (future)
- **Pro** (₹999–1,999/mo or annual): Claude + OpenAI access, ElevenLabs voice, priority, unlimited history
- **Enterprise** (₹50K–5L/year): On-prem gateway option, SSO, audit logs, custom fine-tunes, DPDP compliance package
- **Government / Education**: Special pricing + grant co-funding
- **Future**: White-label SDK, marketplace of "skills" (India-specific agents)

**High LTV, low CAC** (organic via product + community).

---

## Slide 9: Traction & Current State (July 2026)
✅ Fully functional macOS app (SwiftUI + AppKit)  
✅ DMG installer ready (auto-built via GitHub Actions on macOS 15)  
✅ GitHub: https://github.com/skmandal3240/ALICE (public, MIT)  
✅ Logo + branding complete (futuristic orb)  
✅ All bugs fixed, TypeScript gateway compiles clean  
✅ CI/CD for DMG, signed builds possible  
✅ Zero references to any prior project — 100% clean-room  

**Product is shippable today.**  
**Company formation + grant applications are the next step.**

---

## Slide 10: Roadmap (India-first)
**2026 H2**
- Company incorporation (Delhi/Bangalore/Bihar)
- Apply to: SISFS, MeitY TIDE 2.0 / SAMRIDH, IndiaAI, NIDHI-PRAYAS, Bihar Startup Policy
- Add Hindi + 3 major Indian language voice support
- Windows beta
- On-device model integration (privacy-first default)

**2027**
- Linux support
- Enterprise pilots (IITs, government departments, unicorns)
- "ALICE for Bharat" — low-cost version for Tier-2/3 via local models
- Marketplace of domain agents (legal, research, policy)

**Vision 2028**: The default private AI layer for every Indian knowledge worker.

---

## Slide 11: Team & Why Now
**Founder**: Saurabh Mandal — deep experience building production AI products (SIA, ASTRO, ALICE). Grant-focused from day one.

**Why this team wins**:
- Already shipped working product (not just deckware)
- Obsessed with privacy + India sovereignty
- Full-stack (code + gateway + CI + packaging + design)
- Grant-ready mindset (documentation, demos, compliance)

**Advisors needed**: AI policy (MeitY), enterprise sales, on-device ML.

---

## Slide 12: The Ask
**We are raising a small seed + grant combination to turn ALICE into India's private AI companion company.**

**Funding Ask**:
- **₹1.5–3 Cr** (grant + angel/accelerator)
- Use of funds: 2 engineers + 1 designer + gateway infra + on-device model work + India language data + compliance

**Specific grants targeted**:
- MeitY TIDE 2.0 / SAMRIDH
- IndiaAI Mission
- SISFS
- NIDHI-PRAYAS
- Bihar Startup Policy

**In return**: Equity + milestone-based deliverables (Windows port, 10K users, 3 enterprise pilots).

**We already have the product. We need the runway to make it India's.**

---

## Slide 13: Vision
**Imagine every Indian researcher, officer, founder, and student has a private AI that lives on their desktop — never leaks data, speaks their language, and actually points at what matters.**

**ALICE is not another chatbot.**  
**It is the ambient intelligence layer for the next 100 million knowledge workers.**

**Let's build India's AI companion.**

---

## Contact & Next Steps
**Repo**: https://github.com/skmandal3240/ALICE  
**DMG**: https://github.com/skmandal3240/ALICE/releases  
**Founder**: Saurabh Mandal

**Immediate next actions**:
1. Incorporate company
2. Deploy production gateway in India region (if required)
3. Record 60-second demo video
4. Submit first 3 grant applications

**Ready to talk grants, pilots, or investment.**

---

*Deck version 1.0 — July 2026*  
*Built with ❤️ in India for India*