# Brevo Free SMTP for SolarCare

1. Sign up at https://onboarding.brevo.com/ and keep the **Free** plan. Complete account verification using your real project details. No payment card is needed for the Free plan, which includes 300 email sends per day.
2. In Brevo, open **Settings → Senders, Domains, IPs → Senders → Add a sender**. Use **SolarCare** as the sender name and an email inbox you control. Verify it with the code emailed to that address.
3. Open **Settings → SMTP & API → SMTP**. Copy the **SMTP login**, then generate a **Standard SMTP key** named `SolarCare Supabase`. Save it privately; the full key is shown only once.
4. Open the SolarCare Supabase project's custom SMTP page: https://supabase.com/dashboard/project/usgdrzubndfvfarkklok/auth/smtp . Enable custom SMTP and enter:

| Supabase field | Value |
| --- | --- |
| Sender email | The email address verified in Brevo |
| Sender name | SolarCare |
| Host | smtp-relay.brevo.com |
| Port | 587 |
| Username | SMTP login copied from Brevo |
| Password | The generated Brevo SMTP key |

Use the SMTP key as the password; your Brevo account password and API key are different credentials. Do not use the technical SMTP login as the sender email.

5. Save the settings. Keep email confirmation enabled in Supabase's email provider settings. In **Authentication → URL Configuration**, use `http://localhost:8080/` as the Site URL for desktop browser testing. Replace it with the assigned public Netlify URL after deployment. Mobile email confirmation needs a reachable public URL or a configured app deep link.
6. Try a real sign-up using another email inbox you control. Check the confirmation email and Brevo's transactional logs. If Brevo reports that the SMTP account is not activated, request transactional sending activation through Brevo support.

## Without an owned domain

A Gmail sender can be verified as an individual address, but you cannot authenticate `gmail.com` as your own domain. Brevo documents a temporary sender-address replacement using its own domain for unauthenticated/free senders, including transactional messages. This is a temporary testing option, subject to account activation and actual delivery checks. Use your own authenticated sending domain for launch; the free Netlify subdomain does not give you control of its email-domain DNS.

Supabase initially limits custom SMTP auth emails to 30 per hour. Brevo's 300-per-day allowance is a separate provider limit, shared across emails sent from your Brevo account. Keep the Free plan and avoid paid add-ons. No SMTP credentials are stored in this project.

Sources:
- https://help.brevo.com/hc/en-us/articles/208580669-FAQs-What-are-the-limits-of-the-Free-plan
- https://www.brevo.com/products/transactional-email/
- https://help.brevo.com/hc/en-us/articles/208836149-Create-a-new-sender-From-name-and-From-email
- https://help.brevo.com/hc/en-us/articles/7959631848850-Create-and-manage-your-SMTP-keys
- https://help.brevo.com/hc/en-us/articles/7924908994450-Send-transactional-emails-using-Brevo-SMTP
- https://help.brevo.com/hc/en-us/articles/14925263522578-Comply-with-Gmail-Yahoo-and-Microsoft-s-requirements-for-email-senders
- https://help.brevo.com/hc/en-us/articles/115000188150-Troubleshooting-Issues-with-Brevo-SMTP
- https://supabase.com/docs/guides/auth/auth-smtp
