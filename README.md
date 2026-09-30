# QuickSnip

**Your saved replies, one click away on your Mac.**

QuickSnip keeps the messages you write again and again (welcomes, rule reminders, warnings) organized in folders in your menu bar. Click one and it's copied, ready to paste anywhere.

- **Folders and subfolders** keep everything organized.
- **Quick Snippets** are small notepads for text you need right now.
- **Keyboard shortcuts for anything**: open a folder, copy a snippet or open a Quick Snippet from any app.
- **Quick menu at your pointer**: press **Control + Option + S** in any app.
- **Private**: your snippets stay on your Mac. QuickSnip never reads or saves anything else you copy.
- **Free**, and it keeps itself up to date.

Requires macOS 13 Ventura or later. Works on Apple Silicon and Intel Macs.

<p align="center">
  <img src="docs/panel-categories.png" width="260" alt="The QuickSnip panel showing a list of folders">
  <img src="docs/panel-add.png" width="260" alt="Inside a folder, the + button offers Add Snippet and Add Subfolder">
  <img src="docs/panel-snippets.png" width="260" alt="A list of snippets, each with a preview of its text">
</p>

---

## Download

**[Download QuickSnip](https://github.com/2819-dev/Work-Universe/releases/latest/download/QuickSnip.zip)**

---

## Install

1. Open your **Downloads** folder and double-click **QuickSnip.zip**. A **QuickSnip** folder appears.
2. Drag the **QuickSnip** app into your **Applications** folder.
3. Open **Applications** and double-click **QuickSnip**.

### The first time you open it

QuickSnip is distributed independently rather than through the App Store, so macOS asks you to confirm the first time you open it:

1. When macOS says it can't verify **QuickSnip**, click **Done**.
2. Open **System Settings** and choose **Privacy & Security**.
3. Scroll down to **Security** and click **Open Anyway** next to "QuickSnip was blocked".
4. Confirm with your password or Touch ID, then click **Open Anyway**.

You only need to do this once. When QuickSnip opens, a **✂︎ scissors** icon appears in your menu bar and the QuickSnip panel slides in from the right.

---

## Using QuickSnip

### Copy a snippet

1. Click the **✂︎** in the menu bar. The QuickSnip panel opens on the right side of your screen.
2. Click a **folder** to open it.
3. Click a **snippet**. It's copied, and you'll see **"Copied: [snippet name]"**.
4. Click where you want the text and press **⌘ Command + V** to paste.

### Quick menu from any app

Press **Control + Option + S** and a menu opens right at your pointer. Choose a folder, then a snippet, and it's copied.

### Add folders and Quick Snippets

On the main page of the panel, hover over (or click) the blue **+** button:

- **New Folder** creates a folder for a group of snippets.
- **New Quick Snippet** opens a small notepad.

### Add snippets and subfolders

1. Open a folder.
2. Hover over (or click) the blue **+** button:
   - **Add Snippet**: give it a title (the name you'll see in the list) and the text you want copied, then click **Save**.
   - **Add Subfolder**: a folder inside the folder, for grouping related snippets.
3. Inside a subfolder, the **+** button adds a snippet straight away.

### Quick Snippets

A Quick Snippet is a small notepad for text you need right now: a draft announcement, a list of links, notes from a discussion. It opens in its own window, stays on top while you work and saves as you type. Click **Copy** (or press **⌘ Command + Return**) to copy everything in it. The first line becomes its name.

### Keyboard shortcuts for anything

Right-click any folder, subfolder, snippet or Quick Snippet and choose **Keyboard Shortcut…**, then press the keys you want, for example **Control + Option + W**.

| Shortcut for a… | What it does |
|---|---|
| Folder or subfolder | Opens it in the QuickSnip panel |
| Snippet | Copies it instantly |
| Quick Snippet | Opens its notepad |

Items with a shortcut show it in the list. To see or change all of them, click **•••** → **Keyboard Shortcuts…**

### Edit, rename or delete

- **Edit a snippet:** hover over it and click the ✎ pencil.
- **More options:** right-click anything to rename, edit, delete or set a keyboard shortcut.

### Close the panel

Click the **✕**, press **Esc**, or click the ✂︎ again. It also closes by itself when you click into another app.

---

## Settings and help

Click the **•••** button at the top of the main panel.

| Item | What it does |
|---|---|
| **Keyboard Shortcuts…** | See and change all your shortcuts, including the quick menu shortcut. |
| **Open at Login** | Start QuickSnip automatically when you turn on your Mac. Recommended. |
| **Show Library in Finder** | Shows where your snippets are saved, so you can back them up. |
| **Check for Updates…** | Checks whether a newer version is available. |
| **About QuickSnip** | Version details and credits. |
| **Support** | The user guide, a form to report a problem, and answers to common questions. |
| **Quit QuickSnip** | Closes QuickSnip. To reopen it, open it from Applications. |

**Tip:** right-click the ✂︎ in the menu bar for the quick menu.

---

## Updating

QuickSnip keeps itself up to date. When a new version is available, the bottom of the panel shows **Update available**. Click **Update**, and QuickSnip downloads the new version, installs it and reopens by itself within a few seconds.

Your snippets are saved separately from the app, so updating never affects them.

**Used Snippet Menu before?** Snippet Menu is now QuickSnip. Click **Update** as usual: the app is renamed automatically, and your snippets and settings come with it.

---

## Troubleshooting

**I don't see the ✂︎ in my menu bar.**
The menu bar may be full, especially on MacBooks with a camera notch, where macOS hides icons that don't fit. Quit another menu bar app to make room. Keyboard shortcuts always work.

**"Open Anyway" isn't showing in Privacy & Security.**
It only appears for a short while after you try to open the app. Double-click **QuickSnip** in Applications again, then return to **Privacy & Security**.

**A keyboard shortcut doesn't do anything.**
Another app may be using the same combination. Choose a different one under **••• → Keyboard Shortcuts…**

**"Open at Login" won't turn on.**
Open **System Settings → General → Login Items**, click **+** under "Open at Login", and choose **QuickSnip**.

**The update couldn't be installed.**
QuickSnip can only update itself when it's in your **Applications** folder. Move it there and try again, or click **Open Download Page** and install the new version by hand (see **Install** above).

**My snippets are missing.**
If the panel says your library couldn't be found, it was moved or deleted. Restore it from a backup to the location shown by **Show Library in Finder**, or click **Create New Library** to start fresh.

**Something else?**
[Report a problem](https://github.com/2819-dev/Work-Universe/issues/new?template=problem.yml) or [ask a question](https://github.com/2819-dev/Work-Universe/issues/new?template=question.yml).

---

## Uninstall

1. Click **•••** → **Quit QuickSnip**.
2. Drag **QuickSnip** from **Applications** to the **Trash**.
3. Optional: to also delete your snippets, click **Go → Go to Folder…** in Finder, enter `~/Library/Application Support/QuickSnip`, and move that folder to the Trash.

---

QuickSnip is made by **BigHappySmiley**.
