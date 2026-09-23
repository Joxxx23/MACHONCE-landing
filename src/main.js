import { startIntro } from './intro.js';
import { submitEmail } from './waitlist.js';

const brand = document.querySelector('.brand');
const video = document.querySelector('video');
if (document.documentElement.classList.contains('intro-pending') &&
    brand instanceof HTMLElement && video instanceof HTMLVideoElement) {
  startIntro(brand, video);
}
document.documentElement.classList.remove('intro-pending');

const form = document.querySelector('form');
const email = document.querySelector('#email');
const consent = document.querySelector('#consent');
const button = document.querySelector('button');
const message = document.querySelector('#waitlist-message');

if (form instanceof HTMLFormElement && email instanceof HTMLInputElement &&
    consent instanceof HTMLInputElement &&
    button instanceof HTMLButtonElement && message instanceof HTMLElement) {
  consent.checked = false;
  button.disabled = false;

  /** @param {string} text @param {'info' | 'error'} kind */
  function showMessage(text, kind) {
    if (!(message instanceof HTMLElement)) return;
    message.textContent = text;
    message.dataset.kind = kind;
  }

  email.addEventListener('input', () => {
    email.removeAttribute('aria-invalid');
    showMessage('', 'info');
  });

  consent.addEventListener('change', () => {
    consent.removeAttribute('aria-invalid');
    showMessage('', 'info');
  });

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (button.disabled) return;
    email.value = email.value.trim();

    if (!email.validity.valid) {
      email.setAttribute('aria-invalid', 'true');
      showMessage(email.validity.valueMissing
        ? 'Please enter your email address.'
        : 'Please enter a valid email address.', 'error');
      email.focus();
      return;
    }

    email.removeAttribute('aria-invalid');
    if (!consent.checked) {
      consent.setAttribute('aria-invalid', 'true');
      showMessage('Please confirm that you’d like to receive MACHONCE early-access emails.', 'error');
      consent.focus();
      return;
    }

    consent.removeAttribute('aria-invalid');
    button.disabled = true;
    button.textContent = 'SUBMITTING…';
    email.readOnly = true;
    consent.disabled = true;
    form.setAttribute('aria-busy', 'true');
    showMessage('', 'info');

    try {
      await submitEmail(email.value, consent.checked);
      showMessage('You’re in.', 'info');
      form.reset();
    } catch {
      showMessage('Something went wrong. Please try again.', 'error');
    } finally {
      button.disabled = false;
      button.textContent = 'GET EARLY ACCESS';
      email.readOnly = false;
      consent.disabled = false;
      form.removeAttribute('aria-busy');
    }
  });
}
