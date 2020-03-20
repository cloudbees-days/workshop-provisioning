const puppeteer = require('puppeteer');

const args = require('minimist')(process.argv.slice(2));

function checkArgs() {
  if (!args.secret) throw new Error("You need to include a secret!!!");
  if (!args.username) throw new Error("You need to include an admin username!!!");
  if (!args.password) throw new Error("You need to include an admin password!!!");
  if (!args.email) throw new Error("You need to include an email!!!");
  if (!args.url) throw new Error("You need to include a URL")
}
console.log(args)
checkArgs();

async function router(page) {
  await page.waitFor(2000)
  try {
    const title = await page.$eval('h1', el => el.textContent);
    switch (title) {
      case "Unlock CloudBees Core Cloud Operations Center":
        handleUnlock(page)
        break;
      case "License":
        requestTrialLicense(page)
        break;
      case "Customize CloudBees Core Cloud Operations Center":
        installRecommended()
        break;
      case "Incremental Upgrade Available":
        incrementalUpgrade();
        break;
      case "Create First Admin User":
        createAdminUser()
        break;
      case "CloudBees Core Cloud Operations Center is almost ready!":
        restart()
        break;
    }
  } catch (error) {
    console.log("No H1 found on the page")
    console.error(error)
  }
}

async function handleUnlock(page) {
  await page.type("input[name=j_password]", args.secret)
  await page.click('.set-security-key')
  await router(page)
}

async function requestTrialLicense(page) {
  await page.click("#btn-com_cloudbees_opscenter_server_license_OperationsCenterEvaluationRegistrar")
  await freeTrial(page)
}

async function freeTrial(page) {
  await page.waitFor(3000)
  await page.type("input[name=firstName]", "Workshop")
  await page.type("input[name=lastName]", "Owner")
  await page.type("input[name=email]", args.email)
  await page.type("input[name=company]", "CloudBees")
  await page.click("input[name=agree]")
  await page.click("#main-panel > div > div > div > div > div > div.modal-footer.cb-registration-form > button.btn.btn-primary.pull-right")
  await router(page)
}

async function installRecommended(page) {
  await page.click("#main-panel > div > div > div > div > div > div.modal-body > div > p.button-set > a.btn.btn-primary.btn-lg.btn-huge.install-recommended")
  await router(page)
}

async function incrementalUpgrade(page) {
  await page.click("#install-plugins-button")
  await page.waitFor(5000)
  await router(page)
}

async function createAdminUser(page) {
  await page.type("input[name=username]", args.username)
  await page.type("input[name=password1]", args.password)
  await page.type("input[name=password2]", args.password)
  await page.type("input[name=fullname]", "Workshop Owner")
  await page.type("input[name=email]", args.email)
  await page.click("#main-panel > div > div > div > div > div > div.modal-footer > button.btn.btn-primary.save-first-user")
  await router(page)
}

async function restart(page) {
  await page.click("#main-panel > div > div > div > div > div > div.modal-body > div > button")
}

(async () => {
  const browser = await puppeteer.launch({ ignoreHTTPSErrors: true });
  const page = await browser.newPage();
  await page.goto(args.url);
  try {
    router(page)


  } catch (error) {
    console.error(error)
  }
  await page.waitFor(5000)
  await page.screenshot({ path: "break.png" })

  await browser.close()
})();