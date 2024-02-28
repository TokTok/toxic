import { test, expect, Shell } from "@microsoft/tui-test";

test.use({ shell: Shell.Bash, rows: 25, columns: 90 });

const fast = { timeout: 100 };
const slow = { timeout: 1000 };

async function startToxic(terminal: Shell.Terminal) {
  terminal.write("toxic\r");
  return expect(terminal.getByText("Welcome to Toxic")).toBeVisible(slow);
}

test.describe("toxic", () => {
  test("toxic --help shows usage message", async ({ terminal }) => {
    terminal.write("toxic --help\r");
    await expect(terminal.getByText("usage: toxic")).toBeVisible(fast);
    await expect(terminal).toMatchSnapshot();
  });

  test("toxic shows intro message", async ({ terminal }) => {
    terminal.write("toxic\r");
    await expect(
      terminal.getByText("Would you like to encrypt it")
    ).toBeVisible(fast);
    terminal.write("n\r");
    await expect(terminal.getByText("Welcome to Toxic")).toBeVisible(slow);
    await expect(terminal).toMatchSnapshot();
  });

  test("help window works", async ({ terminal }) => {
    await startToxic(terminal);
    terminal.write("/help\r");
    await expect(terminal.getByText("Help Menu")).toBeVisible(fast);
    await expect(terminal).toMatchSnapshot();
  });

  test("global help window works", async ({ terminal }) => {
    await startToxic(terminal);
    terminal.write("/help\r");
    await expect(terminal.getByText("Help Menu")).toBeVisible(fast);
    terminal.write("g");
    await expect(terminal.getByText("Global Commands")).toBeVisible(fast);
    await expect(terminal).toMatchSnapshot();
  });

  test("help window can be exited", async ({ terminal }) => {
    await startToxic(terminal);
    terminal.write("/help\r");
    await expect(terminal.getByText("Help Menu")).toBeVisible(fast);
    terminal.write("x");
    await expect(terminal.getByText("Help Menu")).not.toBeVisible(fast);
    await expect(terminal).toMatchSnapshot();
  });

  test("terminal resize works", async ({ terminal }) => {
    await startToxic(terminal);
    terminal.write("/help\r");
    await expect(terminal.getByText("Help Menu")).toBeVisible(fast);
    terminal.resize(60, 20);
    await expect(terminal.getByText("Help Menu")).toBeVisible(fast);
    // Wait for one of the last things to be drawn before screenshotting.
    await expect(terminal.getByText("[Contacts]")).toBeVisible(fast);
    await expect(terminal).toMatchSnapshot();
  });

  test("last message is shown when terminal gets smaller", async ({ terminal }) => {
    await startToxic(terminal);
    // Add a friend.
    terminal.write("/add 13117C65771C5A05409F532A7809D238E38E94312C870FE7970C5B65B1215E20CEF40A1D48B7\r");
    await expect(terminal.getByText("Friend request sent.")).toBeVisible(fast);
    terminal.write(String.fromCharCode(16));
    await expect(terminal.getByText("Press the h key")).toBeVisible(fast);
    terminal.write("\r");
    await expect(terminal.getByText("[Offline]")).toBeVisible(fast);
    for (let i = 1; i <= 10; ++i) {
        terminal.write(`we're (${i}) writing some pretty long message here, this is message ${i}\r`);
    }
    await expect(terminal.getByText("message 10")).toBeVisible(fast);
    terminal.resize(60, 20);
    // slow, because resize can take a while
    // TODO(JFreegman): Make this "message 10" when it's fixed.
    await expect(terminal.getByText("message 7")).toBeVisible(slow);
    await expect(terminal).toMatchSnapshot();
  });
});
