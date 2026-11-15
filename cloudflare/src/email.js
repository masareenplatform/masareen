export const SITE_URL = 'https://masareen.com';

const escapeHtml = (value) => String(value ?? '')
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&#39;');

export async function sendEmail(env, msg) {
  if (!env.RESEND_API_KEY) return { ok: false, skipped: true };
  try {
    const r = await (env.__fetch || fetch)('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(msg),
    });
    if (!r.ok) {
      const text = await r.text().catch(() => '');
      console.error('resend_error', r.status, text.slice(0, 200));
      return { ok: false, status: r.status };
    }
    return { ok: true, ...(await r.json().catch(() => ({}))) };
  } catch (error) {
    console.error('resend_exception', error);
    return { ok: false };
  }
}

export function masareenEmailLayout({ preheader, title, bodyHtml, ctaText, ctaUrl, footerExtra = '' }) {
  const logoUrl = `${SITE_URL}/assets/mark.png`;
  const bg = '#f4f7f6';
  const card = '#ffffff';
  const primary = '#0f3d3e';
  const accent = '#1fb8b8';
  const gold = '#b9a06c';
  const text = '#1f2937';
  const muted = '#6b7280';
  const border = '#e5e7eb';
  return `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${escapeHtml(title)}</title><style>
body{margin:0;background:${bg};font-family:Inter,Segoe UI,Helvetica,Arial,sans-serif;color:${text}}
.pre{display:none!important;max-height:0;overflow:hidden;opacity:0}
.wrap{max-width:640px;margin:0 auto;padding:24px}
.header{background:linear-gradient(135deg,${primary} 0%,#123d3e 60%,${accent} 140%);border-radius:18px 18px 0 0;padding:30px 32px;text-align:center}
.logo{width:76px;height:76px;border-radius:18px;box-shadow:0 10px 30px rgba(0,0,0,.18);background:#fff;padding:6px}
.card{background:${card};border:1px solid ${border};border-top:none;border-radius:0 0 18px 18px;padding:36px 32px;box-shadow:0 30px 60px rgba(15,61,62,.08)}
h1{margin:0 0 12px;font-size:26px;line-height:1.25}
.lead{color:${muted};font-size:16px;line-height:1.7;margin:0 0 24px}
.body{font-size:16px;line-height:1.8}
.cta{display:inline-block;background:linear-gradient(90deg,${accent} 0%,#22d3ee 100%);color:#fff;text-decoration:none;padding:14px 28px;border-radius:999px;font-weight:700;box-shadow:0 18px 40px rgba(31,184,184,.18)}
.alt{display:block;margin-top:18px;color:${muted};font-size:12px;line-height:1.7;word-break:break-all}
.divider{height:1px;background:${border};margin:32px 0}
.footer{max-width:640px;margin:16px auto 40px;text-align:center;color:${muted};font-size:13px;line-height:1.8}
.tag{display:inline-block;margin-top:12px;padding:6px 14px;border-radius:999px;border:1px solid rgba(185,160,108,.45);color:${gold};font-size:12px;letter-spacing:.18em;text-transform:uppercase}
.code{font-size:28px;letter-spacing:8px;font-weight:800;color:${primary};background:#f0fdfa;border:1px solid #ccfbf1;border-radius:14px;padding:14px 18px;text-align:center}
@media(max-width:520px){.card,.header{padding:24px}}
</style></head><body><span class="pre">${escapeHtml(preheader || '')}</span><div class="wrap"><div class="header"><img class="logo" src="${logoUrl}" alt="MASAREEN"></div><div class="card"><h1>${escapeHtml(title)}</h1>${bodyHtml}<div style="text-align:center;margin-top:32px">${ctaText && ctaUrl ? `<a class="cta" href="${escapeHtml(ctaUrl)}">${escapeHtml(ctaText)}</a>` : ''}</div><div class="divider"></div><div class="body" style="color:${muted};font-size:15px"><p style="margin:0">With gratitude,<br><strong style="color:${text}">The MASAREEN Team</strong></p></div></div></div><div class="footer"><div>MASAREEN · https://masareen.com</div><div class="tag">Building trusted knowledge for a connected future</div>${footerExtra ? `<div>${footerExtra}</div>` : ''}</div></body></html>`;
}

export function verificationEmail({ name, verifyUrl, expiresHours = 24 }) {
  const first = escapeHtml((name || '').split(/\s+/)[0] || 'there');
  const subject = 'Confirm your MASAREEN email';
  const bodyHtml = `<p class="lead">Assalamu Alaikum ${first}, please confirm your email to activate your MASAREEN account.</p><div class="body"><p>Tap the button below to verify your email address. The link expires in ${expiresHours} hours.</p><p>If you did not create this account, you can safely ignore this message.</p></div>`;
  const html = masareenEmailLayout({
    preheader: 'Confirm your MASAREEN email',
    title: 'Confirm your email',
    bodyHtml,
    ctaText: 'Verify email',
    ctaUrl: verifyUrl,
  });
  return { subject, html };
}

export function passwordResetEmail({ name, resetUrl, expiresMinutes = 60 }) {
  const first = escapeHtml((name || '').split(/\s+/)[0] || 'there');
  const subject = 'Reset your MASAREEN password';
  const bodyHtml = `<p class="lead">Hi ${first}, we received a request to reset your MASAREEN password.</p><div class="body"><p>Use the button below to choose a new password. The link expires in ${expiresMinutes} minutes and can be used once.</p><p>If you did not request this, you can ignore this email. Your password will not change.</p></div>`;
  const html = masareenEmailLayout({
    preheader: 'Reset your MASAREEN password',
    title: 'Choose a new password',
    bodyHtml,
    ctaText: 'Reset password',
    ctaUrl: resetUrl,
  });
  return { subject, html };
}

export function welcomeEmail({ name, url = SITE_URL }) {
  const first = escapeHtml((name || '').split(/\s+/)[0] || 'there');
  const subject = 'Welcome to MASAREEN';
  const bodyHtml = `<p class="lead">Assalamu Alaikum ${first}, and a warm welcome to MASAREEN.</p><div class="body"><p>Your email is confirmed. You are now part of a community of students, researchers, institutions and changemakers making credible knowledge easier to verify, share and act on.</p><p><strong>Complete your profile</strong> to help us tailor the experience to your goals, then explore the impact feed and marketplace opportunities.</p><p>If you ever need help, reply to this message and our team will get back to you.</p></div>`;
  const html = masareenEmailLayout({
    preheader: 'Welcome to MASAREEN',
    title: 'Welcome to MASAREEN',
    bodyHtml,
    ctaText: 'Open MASAREEN',
    ctaUrl: url,
  });
  return { subject, html };
}

export function passwordChangedEmail({ name, when }) {
  const first = escapeHtml((name || '').split(/\s+/)[0] || 'there');
  const subject = 'Your MASAREEN password was changed';
  const bodyHtml = `<p class="lead">Hi ${first}, your MASAREEN password was changed on ${escapeHtml(when || 'just now')}.</p><div class="body"><p>If this was you, no action is needed. If you did not make this change, reset your password immediately and contact our team.</p></div>`;
  const html = masareenEmailLayout({
    preheader: 'Your MASAREEN password was changed',
    title: 'Password changed',
    bodyHtml,
    ctaText: 'Reset password',
    ctaUrl: `${SITE_URL}/api/v1/auth/reset-password`,
  });
  return { subject, html };
}

export async function sendVerificationEmail(env, user, verifyUrl, expiresHours = 24) {
  if (!env.RESEND_API_KEY) return { ok: false, skipped: true };
  const mail = verificationEmail({ name: user.name, verifyUrl, expiresHours });
  return sendEmail(env, {
    from: env.MAIL_FROM || 'MASAREEN <onboarding@resend.dev>',
    to: [user.email],
    subject: mail.subject,
    html: mail.html,
    reply_to: env.MAIL_REPLY_TO || undefined,
  });
}

export async function sendPasswordResetEmail(env, user, resetUrl, expiresMinutes = 60) {
  if (!env.RESEND_API_KEY) return { ok: false, skipped: true };
  const mail = passwordResetEmail({ name: user.name, resetUrl, expiresMinutes });
  return sendEmail(env, {
    from: env.MAIL_FROM || 'MASAREEN <onboarding@resend.dev>',
    to: [user.email],
    subject: mail.subject,
    html: mail.html,
    reply_to: env.MAIL_REPLY_TO || undefined,
  });
}

export async function sendWelcomeEmail(env, user, url = SITE_URL) {
  if (!env.RESEND_API_KEY) return { ok: false, skipped: true };
  const mail = welcomeEmail({ name: user.name, url });
  return sendEmail(env, {
    from: env.MAIL_FROM || 'MASAREEN <onboarding@resend.dev>',
    to: [user.email],
    subject: mail.subject,
    html: mail.html,
    reply_to: env.MAIL_REPLY_TO || undefined,
  });
}

export async function sendPasswordChangedEmail(env, user, when) {
  if (!env.RESEND_API_KEY) return { ok: false, skipped: true };
  const mail = passwordChangedEmail({ name: user.name, when });
  return sendEmail(env, {
    from: env.MAIL_FROM || 'MASAREEN <onboarding@resend.dev>',
    to: [user.email],
    subject: mail.subject,
    html: mail.html,
    reply_to: env.MAIL_REPLY_TO || undefined,
  });
}

export { escapeHtml };
