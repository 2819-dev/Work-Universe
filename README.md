# Snippet Menu for Mac

A small ✂︎ scissors icon in your Mac's menu bar that holds your own ready-made replies for community moderation.
Click a reply and its text is copied, so you can paste it wherever you need it.

- **Only your snippets.** The menu shows only what you write in your snippets file.
- **Not a clipboard manager.** It never reads, records, or saves anything you copy.
- **It doesn't paste for you.** It only copies. You choose where to paste, with **⌘ Command + V**.
- **Free.** No purchase and no Apple Developer account needed.
- Works on **macOS 13 (Ventura) or newer**, on Apple Silicon and Intel Macs.

---

## 1. Install (one time, about 5 minutes)

### Step 1: Download

1. Open the **[latest release](https://github.com/2819-dev/Work-Universe/releases/latest)**.
2. Under **Assets**, click **Snippet-Menu.zip**. It downloads to your **Downloads** folder.
3. Double-click **Snippet-Menu.zip** in Downloads. A folder called **Snippet Menu** appears.

### Step 2: Move the app into Applications

1. Open the **Snippet Menu** folder.
2. Drag **Snippet Menu** (the app with the scissors icon) into your **Applications** folder.
   Open a second Finder window with **⌘ Command + N** and click **Applications** in the sidebar if you need a place to drop it.

### Step 3: Open it the first time

Because the app is free and isn't registered with Apple (that costs $99/year), macOS blocks it the first time. You only need to allow it **once**:

1. In **Applications**, double-click **Snippet Menu**.
2. A message says Apple "could not verify" it or that it "can't be opened". Click **Done** (or **OK**). **Don't** click "Move to Trash".
3. Open **System Settings** (Apple menu  → System Settings) and click **Privacy & Security** in the sidebar.
4. Scroll down to the **Security** section. You'll see *"Snippet Menu" was blocked…*. Click **Open Anyway**.
5. Enter your Mac password (or use Touch ID) if asked, then click **Open Anyway** again.

A **✂︎ scissors icon** appears in your menu bar (top-right of your screen), along with a short "Snippets ready" message. You're done!

After this, it opens normally, with no more warnings.

> **Can't see the scissors?** If your menu bar is crowded, macOS hides icons that don't fit, especially on MacBooks with a camera notch. Quit another menu bar app to make room. The keyboard shortcut (below) works either way.

### Step 4: Start it automatically (recommended)

Click **✂︎** and choose **Open at Login**. A checkmark means it starts every time you turn on your Mac.

---

## 2. Everyday use

1. Press **Control + Option + S** in any app (or click **✂︎** in the menu bar).
   The menu opens right where your mouse pointer is.
2. Point at a **category**, then a **subcategory** if it has one, then click a **snippet**.
   Hover over a snippet for a moment to preview its text.
3. A message says **"Copied: [snippet title]"**.
4. Click where you want the text and press **⌘ Command + V** to paste.

To close the menu without choosing anything, press **Esc** or click elsewhere.

---

## 3. Writing your own snippets

Click **✂︎ → Edit snippets…**. Your snippets file opens in TextEdit.
The app comes with example moderation replies. Replace them with your own.

Start a line with these markers, each followed by a space:

| Start the line with | What it means |
|---|---|
| `# ` | A **category**, the top-level menu item |
| `## ` | A **subcategory** inside that category (optional) |
| `### ` | A **snippet title**, the name you see in the menu |
| anything else | The **text of the snippet** above it. This is what gets copied. It can be many lines. |

Example:

```
# Rule reminders

## Spam

### Self-promo reminder
Hi! Just a friendly reminder that self-promotion isn't allowed
outside the designated thread.

### Spam removed
This post was removed because it was identified as spam.

# Welcome

### Welcome new member
Hi and welcome to the community! 👋
```

**Save with ⌘ Command + S.** The menu picks up your changes the next time you open it. There's nothing to restart.

Tips:

- **Subcategories are optional.** A snippet can sit directly under a category, like "Welcome new member" above.
- **Blank lines inside a snippet are kept.** Blank lines at its very start or end are trimmed.
- **Notes before the first `#` line are ignored**, so you can keep reminders to yourself at the top.
- **Emoji and other languages are fine.**
- TextEdit may turn straight quotes into curly ones as you type. To stop that: **Edit → Substitutions →** untick **Smart Quotes**.
- **Back it up:** **✂︎ → Show snippets file in Finder** shows where it lives. Copy that `snippets.txt` somewhere safe from time to time.

---

## 4. Changing the keyboard shortcut

1. **✂︎ → Edit snippets…**
2. Near the top, find this line:

   ```
   Shortcut: control+option+s
   ```

3. Change it. Put the key names in any order, joined with `+`:
   - Modifiers: `control`, `option`, `command`, `shift`. Use at least one of control, option, or command.
   - The key: a letter, a number, or `f1`–`f12`.
   - Example: `Shortcut: command+shift+m`
4. Save. The new shortcut works the next time you open the ✂︎ menu (click it once).

The current shortcut is always shown near the bottom of the ✂︎ menu.
If the new one doesn't work, another app is probably using it, so pick a different combination.

---

## 5. The ✂︎ menu, item by item

| Item | What it does |
|---|---|
| Your categories | Your snippets. Click one to copy it. |
| Shortcut: ⌃⌥S | Shows your current keyboard shortcut (⌃ = Control, ⌥ = Option, ⇧ = Shift, ⌘ = Command). |
| Edit snippets… | Opens your snippets file in TextEdit. |
| Show snippets file in Finder | Shows where the file is stored, for backups. |
| Reload snippets | Re-reads the file now and tells you about any mistakes. |
| Open at Login | Starts Snippet Menu automatically when your Mac starts. |
| Quit Snippet Menu | Closes the app. Open it from Applications to bring it back. |

---

## 6. If something goes wrong

If there's a problem with your snippets file, the app shows a message explaining it. The ✂︎ menu also shows **⚠️ … Show details…** so you can see it again.

| Message | What to do |
|---|---|
| "Couldn't find your snippets file" | Choose **✂︎ → Create example snippets file** to make a fresh one. |
| "Your snippets file is empty" | Add at least one category and one snippet. |
| "No snippets found" | Check that snippet titles start with `### `: three hashes **and a space**. |
| "…needs a # Category above it" | Add a `# Category` line above that snippet. |
| "…has no text, so it was left out" | Write some text under that title, or delete the title. |
| "The shortcut … wasn't understood" | Check the `Shortcut:` line (see section 4). |

If only some snippets have mistakes, the rest still work.

**"Open Anyway" isn't there?** It only appears for about an hour after you try to open the app. Double-click **Snippet Menu** in Applications again, then go back to **Privacy & Security**.

**Open at Login didn't stick?** Add it by hand: **System Settings → General → Login Items**, click **+** under "Open at Login", and choose **Snippet Menu**.

---

## 7. Updating to a new version

1. Quit the app: **✂︎ → Quit Snippet Menu**.
2. Download the new **Snippet-Menu.zip** from the [latest release](https://github.com/2819-dev/Work-Universe/releases/latest), then drag the app into Applications and choose **Replace**.
3. Open it. You may need to do **Open Anyway** once more (section 1, step 3).

**Your snippets are kept.** They're stored separately from the app, so replacing the app doesn't touch them.

## 8. Removing it

1. **✂︎ → Quit Snippet Menu**
2. Drag **Snippet Menu** from Applications to the Trash.
3. Optional: to delete your snippets too, in Finder choose **Go → Go to Folder…**, type `~/Library/Application Support/Snippet Menu`, and delete that folder.

---

## Alternative: the Hammerspoon version

This repo also contains `init.lua`, which does the same job inside the free app [Hammerspoon](https://www.hammerspoon.org), if you ever prefer that. To use it:

1. Install Hammerspoon.
2. Put `init.lua` and `snippets.txt` in the `~/.hammerspoon` folder.
3. Click the hammer icon → **Reload Config**.

The shortcut is set in the top lines of `init.lua`. You don't need this if you use the Snippet Menu app.

---

## For maintainers: how releases are made

The app's source code is in `app/`. GitHub Actions builds it on a Mac for every push to `main` (see `.github/workflows/build.yml`). Pushing a tag like `v1.0.1` also publishes a release with `Snippet-Menu.zip`. The app is ad-hoc signed, which is free; it isn't notarized, which is why step 3 above is needed.
