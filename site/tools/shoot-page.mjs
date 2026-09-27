// node site/tools/shoot-page.mjs <url> <out.png> [phone|desktop]: photographs a page at a device size, for the phone
// remote's picture on the website.
import { launchChrome, SIZES } from './cdp.mjs';

const [url, out, size = 'phone'] = process.argv.slice(2);
const chrome = await launchChrome();
try {
  const page = await chrome.newPage({ ...SIZES[size], deviceScaleFactor: 3 });
  await page.goto(url);
  await new Promise((done) => setTimeout(done, 2500));
  await page.screenshot(out);
  console.log(out);
} finally {
  await chrome.close();
}
