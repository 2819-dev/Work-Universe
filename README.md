# Snippet Menu for Mac

A small ✂︎ icon in your Mac's menu bar that holds your own ready-made replies for community moderation.
Click a reply and its text is copied, so you can paste it wherever you need it.

- **Only your snippets.** The menu shows only what you write in `snippets.txt`.
- **Not a clipboard manager.** It never reads, records, or saves anything you copy.
- **It doesn't paste for you.** It only copies. You choose where to paste, with **⌘ Command + V**.
- **Free.** It runs on [Hammerspoon](https://www.hammerspoon.org), a free Mac app.

---

## What you'll get

- A **✂︎** icon in the menu bar. Click it to see your **categories**. Point at a category to open its **subcategories** (if it has any), and then the **snippets**.
- Press **Control + Option + S** in any app to open the same menu right where your mouse pointer is.
- Click a snippet and its full text is copied. A short message says **"Copied: [snippet title]"**.
- Hover over a snippet in the menu to see a preview of its text.
- At the bottom of the menu, **Edit snippets…** opens your snippets file and **Reload snippets** refreshes the menu.

---

## Installing it (about 10 minutes, one time only)

### Step 1: Install Hammerspoon

1. Go to **https://www.hammerspoon.org** and click **Download**.
2. Open the downloaded `.zip` file in your **Downloads** folder. You'll get an app called **Hammerspoon**.
3. Drag **Hammerspoon** into your **Applications** folder.
4. Open **Hammerspoon** from Applications. If your Mac asks *"Are you sure you want to open it?"*, click **Open**.
5. A Hammerspoon settings window appears. Tick these two boxes:
   - **Launch Hammerspoon at login**, so the menu is there every time you start your Mac.
   - **Show menu icon**. This adds a small hammer icon to the menu bar, which you'll use to reload later.
6. If it asks for **Accessibility** permission, click the button. It opens **System Settings → Privacy & Security → Accessibility**. Turn on the switch next to **Hammerspoon**. You may need to type your Mac password.

### Step 2: Allow Hammerspoon's notifications (recommended)

If something is wrong with your snippets file, the menu tells you with an on-screen message and a notification. To make sure the notification shows up:

1. Open **System Settings → Notifications**.
2. Scroll down, click **Hammerspoon**, and turn on **Allow notifications**.

(The "Copied: ..." message appears on screen whether or not you do this.)

### Step 3: Download the files

1. On this GitHub page, click the green **Code** button, then **Download ZIP**.
2. Open the downloaded `.zip`. You'll get a folder containing `init.lua`, `snippets.txt`, and this README.

### Step 4: Put the files in Hammerspoon's folder

Hammerspoon's settings live in a hidden folder called `.hammerspoon` inside your home folder.

1. Click the **hammer icon** in the menu bar and choose **Open Config**. This creates the hidden folder if it doesn't already exist. If a text editor opens, just close it.
2. Click on your desktop so **Finder** is active. In the top menu, choose **Go → Go to Folder…**
3. Type `~/.hammerspoon` and press **Return**. The hidden folder opens.
4. Drag **`init.lua`** and **`snippets.txt`** from the downloaded folder into this `.hammerspoon` folder.
   If Finder says a file named `init.lua` already exists, choose **Replace**. It's only the empty starter file from step 1.

The folder should now contain:

```
.hammerspoon
├── init.lua
└── snippets.txt
```

### Step 5: Turn it on

Click the **hammer icon** in the menu bar and choose **Reload Config**.

You should see **"Snippets loaded"** briefly on screen and a **✂︎** in your menu bar. You're done!

> **Can't see the ✂︎?** If your menu bar is crowded, macOS hides icons that don't fit, especially on MacBooks with a camera notch. Try quitting another menu bar app. **Control + Option + S** works either way.

---

## Everyday use

1. Press **Control + Option + S** (or click **✂︎** in the menu bar).
2. Move to a category, then a subcategory if there is one, then click the snippet.
3. Click where you want the text to go and press **⌘ Command + V** to paste.

---

## Writing your own snippets

Choose **✂︎ → Edit snippets…**. This opens `snippets.txt` in TextEdit.

The file uses a few simple markers at the **start** of a line:

| Start the line with | What it means |
|---|---|
| `# ` (one hash + space) | A **category**, the top-level menu item |
| `## ` (two hashes + space) | A **subcategory** inside that category (optional) |
| `### ` (three hashes + space) | A **snippet title**, the name you see in the menu |
| Anything else | The **text of the snippet** above it. This is what gets copied. It can be many lines long. |

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

Tips:

- **Subcategories are optional.** A snippet can sit directly under a category, like "Welcome new member" above. A category can also mix subcategories and loose snippets.
- **Blank lines inside a snippet are kept.** Blank lines at its very start or end are trimmed off.
- **Notes before the first `#` line are ignored**, so you can keep reminders to yourself at the top.
- **Emoji and other languages are fine.**
- TextEdit may turn straight quotes `"` into curly quotes `" "` as you type. If you don't want that, go to **Edit → Substitutions** in TextEdit and untick **Smart Quotes**.

**After saving the file, choose ✂︎ → Reload snippets** (or hammer icon → Reload Config). The menu is rebuilt from the file every time Hammerspoon reloads.

---

## If something goes wrong

The menu shows a clear message if it can't use your file:

| Message | What to do |
|---|---|
| *"Couldn't find your snippets file"* | Make sure `snippets.txt` is inside the `~/.hammerspoon` folder (see Step 4) and is named exactly `snippets.txt`. |
| *"Your snippets file is empty"* | Add at least one category and one snippet. |
| *"No snippets found"* | Check that your snippet titles start with `### ` (three hashes **and a space**). |
| *"Line 3: snippet ... needs a # Category above it"* | Every snippet must be under a `# Category` line. |
| *"... has no text, so it was left out"* | That snippet title has no text under it. Add some, or delete the title. |

If the problem is only with some snippets, the rest still load normally.

**Nothing happens at all?** Click the hammer icon and choose **Console**. Any error will be shown in red there. If you ask for help, copy and share that text.

---

## Changing the keyboard shortcut

1. Open `init.lua` in TextEdit: in the `~/.hammerspoon` folder, right-click `init.lua` → **Open With → TextEdit**.
2. Near the top, find these two lines:

   ```lua
   local HOTKEY_MODIFIERS = { "ctrl", "alt" }
   local HOTKEY_KEY       = "s"
   ```

3. Change them. Keep the quotes and commas exactly as shown.
   - Modifier names: `"ctrl"` = Control, `"alt"` = Option, `"cmd"` = Command, `"shift"` = Shift
   - The key: a lowercase letter or number, such as `"m"` or `"1"`

   For example, **Command + Shift + M** would be:

   ```lua
   local HOTKEY_MODIFIERS = { "cmd", "shift" }
   local HOTKEY_KEY       = "m"
   ```

4. Save, then click the hammer icon → **Reload Config**.

Choose a combination other apps don't already use. If your shortcut does nothing, it's probably taken, so try another.

You can also change the menu bar symbol (`MENUBAR_TITLE`, currently `"✂︎"`) and how long the "Copied" message stays on screen (`COPIED_MESSAGE_SECONDS`) in the same place.

---

## Removing it

To turn it off, click the hammer icon → **Quit Hammerspoon**, and untick **Launch Hammerspoon at login** in its preferences.
To remove it completely, also drag **Hammerspoon** from Applications to the Trash.
