# AntheticPlus Automations

The 6 Core AI Automations for My Agency

 * AI Multi-Channel Receptionist (Voice + SMS): Answers incoming calls and text messages 24/7, handles caller inquiries, checks live calendar availability, books appointments, and sends instant SMS follow-ups during calls.

 * AI Lead Capture & Smart Qualifier: A lightweight website widget that proactively engages site visitors, asks qualifying questions (budget, timeline, service needed), captures lead details, and routes hot leads to your client's CRM.

 * AI Knowledge Base Support Agent: A 24/7 support agent trained on your client’s specific website, FAQs, and documentation to answer complex customer questions and resolve up to 80% of routine support tickets automatically.

 * AI Social DM & Messaging Assistant: Integrates with WhatsApp, Instagram DMs, and Facebook Messenger to automatically answer product questions, qualify interested buyers, and collect contact details inside social chats.

 * AI Appointment & No-Show Recovery System: Automates booking reminders via SMS/Email, allows patients/clients to reschedule naturally via conversational AI, and automatically re-engages missed appointments to fill open calendar slots.

 * AI Reputation & Review Collector: Automatically sends personalized follow-ups after a completed service, asks for feedback, routes 5-star reviews directly to Google/Trustpilot, and privately captures negative feedback for management review.



Build a Complete Frontend UI for AntheticPlus Studios AI Automation SaaS

1. Brand & Business Context

 * Brand Name: AntheticPlus Studios

 * Founder: Smyight

 * Contact: antheticplusstudios@gmail.com

 * Business Model: We sell high-ticket AI Automations to businesses. Clients purchase a specific automation for their website or phone line, configure its context in our dashboard, and pay manually through a Payment Verifier system (no Stripe).

 * Goal for this prompt: Build the complete frontend UI, responsive layout, animations, navigation, and dummy-data pages for all 6 core AI automations listed below.

2. Visual Aesthetic & Design System

 * Style: Google Material 3 Design principles blended with a clean, high-end SaaS feel (similar to Stripe, Vercel, or Linear).

 * Typography: Clean, punchy, bold sans-serif fonts—specifically Plus Jakarta Sans, Outfit, or Inter. Strictly no robotic or monospace body fonts. Headings should be bold and prominent.

 * UI Polish: High whitespace, rounded corners (Material 3 style), subtle border glows, soft shadows, and clean glassmorphic elements.

 * Animations: Smooth page-fade transitions, tactile hover states on cards and buttons, and subtle micro-interactions. Include a dark/light mode toggle.

3. The 6 Core AI Automations (Build Product Cards & Detail Pages for Each):

 * AI Multi-Channel Voice & SMS Receptionist ($499/mo) - 24/7 call & text answering, live calendar booking, and automatic SMS follow-up.

 * AI Lead Capture & Smart Qualifier ($299/mo) - Proactive web widget that qualifies site visitors and captures contact info into CRMs.

 * AI Knowledge Base Support Agent ($349/mo) - RAG-powered support agent trained on custom documents and FAQs to handle tickets.

 * AI Social DM & Messaging Assistant ($299/mo) - Auto-responder for WhatsApp, Instagram, and Facebook Messenger to capture social leads.

 * AI Appointment & No-Show Recovery ($399/mo) - Automated reminder sequences and conversational re-engagement for canceled/missed bookings.

 * AI Reputation & Review Collector ($199/mo) - Post-service follow-up automation that drives positive Google reviews and flags negative feedback privately.

4. Core Pages to Generate

A. Public Landing Page

 * Hero Section: High-converting headline, bold CTA button ("Explore Automations"), and a interactive preview card showing live AI interaction examples.

 * Automations Grid: Display all 6 automations with custom badges, features list, pricing, and a "View Details & Buy" button.

 * Footer: Include "AntheticPlus Studios, Founded by Smyight" and contact info (antheticplusstudios@gmail.com).

B. Authentication & Profile Setup

 * Sign Up / Login Pages: Centered Material 3 cards for Email/Password sign-up.

 * Complete Profile Banner: A dismissible notice bar on top of the user dashboard stating: "Please complete your company profile to run your active automations."

C. Product Detail Pages (Dynamic Route per Automation)

 * Detailed breakdown of the selected automation, bulleted features list, sample use cases, toggle for Monthly vs. Yearly pricing, and a "Buy Now" button.

D. Multi-Step Checkout / Order Flow

When clicking "Buy Now" on any automation, open a clean 4-step wizard:

 * Step 1: Company Profile (Auto-fills Company Name, Company Email, Website URL, Category).

 * Step 2: AI Context & Instructions (Website Context text area, specific AI instructions, Client ID).

 * Step 3: Billing Plan (Toggle Monthly/Yearly selection).

 * Step 4: Manual Payment Submission (Displays transfer instructions, fields for "Payment Method Used", "Transaction ID / Ref", and "Sender Name").

E. Client Dashboard Shell

 * Sidebar: Dashboard Overview, My Automations, Subscription Payments, Profile Settings.

 * My Automations Table: Columns for Automation Name, Website Domain, Status Badge (Paid, Pending Payment, Stopped, Revoked), Expiration Date, and Action buttons.

 * Automation Management View: Page showing the secret embed script (<script src="...">), AI system prompt editor, and analytics preview.

 * Subscription Payment Tab: Dedicated UI where clients can see unpaid/stopped plans and submit renewal Transaction IDs for approval.

F. Payment Verifier Dashboard (Staff Role UI)

 * A dedicated dashboard view for Payment Verifiers showing pending payment submissions, transaction IDs, client details, and an "Approve Payment" / "Reject" action button. And I send you an Image for the Logo use that exact image for logo everywhere needed. First one is the logo second one is for text logo beside the Logo separately. And make sure my accent color or website theme or logo don't get mixed like in colors like everything can be seen properly make a Professional Best Responsive Clean with Meterial 3 Design website

This project was built with [Lovable](https://lovable.dev).

## Build with Lovable

Continue developing this project in the [Lovable editor](https://lovable.dev/projects/afc3ce58-2d27-47fc-8a24-8ee38d79cbd1).

- **Ship faster**: describe what you want to build and Lovable handles the code.
- **Stay in sync**: every change made in Lovable is committed straight to this repository.
- **Full ownership**: this code is yours. Push to `main` on GitHub and your changes sync back into Lovable, ready for your next prompt.

## Development

Prefer working locally? You need Node.js and npm — [install with nvm](https://github.com/nvm-sh/nvm#installing-and-updating).

```sh
git clone <this-repository-url>
cd <repository-name>
npm i
npm run dev
```
