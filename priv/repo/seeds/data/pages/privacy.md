We may update this document in the future, and will provide a site notice when we do.

---

## The short version

We collect only the bare minimum amount of information that is necessary to protect the service against abuse. We do not sell your information to third parties, and we only use it as this document describes. We aim to be compliant with the EU GDPR.

---

## What information does this site collect and why

**Information from webserver logs**

We collect the following information in webserver logs from every visitor:

- The Internet Protocol (IP) address
- The date and time of the request
- The page that was requested
- The browser user agent string

These items are collected to ensure the security of the service (see "legitimate interests" in the GDPR), and are deleted after 14 days to balance it with user privacy.

**Browser fingerprints**

Browser fingerprints are a tool used to identify users of the service in such a way that administrators will have no knowledge of the individual components of a fingerprint. They are irretrievably hashed (by a browser script) from various browser attributes. As of June 2024, we maintain two distinct versions of the algorithm, which use different properties as components to generate the hash. These are:

**Version 3 (past, used prior to June 15, 2024)**

- Browser user agent string
- Screen width, height, and color depth
- Timezone offset
- Language
- OS name

**Version 4 (current)**

- Browser identity and version
- Screen width, height, and color depth
- Timezone offset
- Language and keyboard layout
- Hardware information (amount of CPU cores and RAM)
- Multi-touch support
- OS information (name, mobile/desktop)

**Information in cookies**

Our cookies for any users of the service may contain this information:

- The unique session token for the website
- User preference for loading high-resolution images
- User preference for loading video previews of animated images
- User preference for website layout customization
- User preference for filtering settings
- One or more "flash" messages (temporary notifications of an action's success or failure, to be displayed at the top of the next page load and then deleted)
- A browser fingerprint

Additionally, cookies of users that are logged in will contain this information:

- An encrypted authentication secret unique to the user to persist their login

Because these are required for authentication, user security, or customization, which are all "legitimate interests", we cannot ask for consent to use cookies.

**Information in user-submitted content**

User-submitted content is considered by us to collectively refer to any content that you may submit to the site, which includes, but is not limited to, comments, images, messages, posts, reports, source changes, tag changes, and votes.

User-submitted content by users (authenticated or not) may have any or all of the following information collected at the time of submission attached, visible only to site staff:

- The IP address
- The browser fingerprint
- The browser user agent string
- The page that initiated the submission

These items are only used for the "legitimate interests" of identifying and controlling abuse of the service and are not shared with any external party.

---

## Information from users with accounts

If you **create an account**, we require some basic information at the time of account creation, as follows:

- a username, shown on your profile and non-anonymous user-submitted content
- a password, stored only as a cryptographic hash
- an email address, shown only to site staff and used only as a means of contact for account control (verification emails, password reset emails, and account unlock emails)

We also store your IP address and browser fingerprint whenever you log in for security reasons.

---

## Information shared with third-party services

We use a few services for security purposes which use personal information. These are as follows:

- To protect against spam, hCaptcha is used. Their privacy policy can be found [here](https://www.hcaptcha.com/privacy).

---

## Information sharing with other parties

Besides services we rely on for security purposes, we only share personal information with third parties in response to court orders.

We display certain statistics about how users use our site (for example, about uploads), without any personal or personally-identifying information.

Many forms of user-submitted content (such as comments or uploads) are viewable by anyone, and as such, may be accessed freely by third parties, including search engines. If a person's personal information is put in such content, we may remove if it we deem it to be too sensitive; inform us if you believe something has been shared that is sensitive.

---

## How we secure your information

We take all measures reasonably necessary to protect account information from unauthorized access, alteration, or destruction.

We use a restrictive content security policy to protect against page hijacking and information leakage to third parties, an image proxy server to avoid leaking user IP address information from embedded images on the site, a cross-origin resource sharing (CORS) policy to restrict third-party usage, a strict referrer policy to prevent leaking data for external links, and an frame policy to prevent clickjacking.

Passwords are hashed using bcrypt at 2^10 iterations with a 128-bit per-user salt.

No method of transmission, or method of electronic storage, is 100% secure. Therefore, we cannot guarantee its absolute security; we only make a best effort.

---

## Complaints and account Personally-Identifiable Information wiping

If you have concerns or objections about the way we handle your personal information, please let us know immediately. You may contact us by PMing a [staff member](/staff).

If you wish to have all stored personal information related to an account removed, you can submit a request for a wipe of personally-identifiable information (PII). If approved (that is, if we do not believe we have a legitimate interest in keeping the information around, such as to preserve evidence of site abuse), the account will be deactivated (can no longer be logged in to) and all personally-identifying information on it, as well as on content submitted with it, will be removed. Since this removes the email address, which is necessary to log in, it is **irreversible**, unlike account deactivation on its own.
