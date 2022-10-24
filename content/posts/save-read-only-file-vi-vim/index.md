---
author: "Armel Soro"
categories: ["Blogs"]
date: 2018-08-15T17:33:00Z
description: ""
draft: false
image: "https://images.unsplash.com/photo-1542852869-ecc293ff89c0?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=2000&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ"
slug: "save-read-only-file-vi-vim"
summary: "How to save a read-only file edited with Vi or Vim without losing your changes"
tags: ["vi", "vim", "root"]
title: "Saving a read-only file edited with Vi/Vim"
resources:
- name: "featured-image"
  src: "featured-image.jpg"

---


It may sometimes happen that you open a system file for edition, forgetting (or not seeing the warning) that the file is actually read-only. Then you make a couple of changes, then try to write the file.A nice message then pops up:

> Can't open file for writing

![vim Error: can't open file for writing](https://rm3l-org.s3-us-west-1.amazonaws.com/assets/vim_cant_open_file_for_writing.png)

Rather than being tempted to exit (_ESC :q!_), lose your changes, reopen the file with _sudo_ (_sudo vim /path/to/my/system/file_) and editing it again, you can use the following interactive command right in Vi/Vim to write your changes:

```
ESC :w !sudo tee %
```

![Interactive save with vim](https://rm3l-org.s3-us-west-1.amazonaws.com/assets/vim_interactive_save_with_sudo.png)

This command will ask for your password, then you will be able to acknowledge the buffer changes or reload the file to its initial state.

At this stage, you will be presented with the content of the file and a prompt to press _ENTER_ or type another command.Then type the letter _O_ to simply save the file and move on.Note that pressing _L_ seems to do pretty much the same thing. The file will be saved but remains opened in Vi/Vim for more editing or reading. We can now exit normally by typing _ESC :q!_ since the file is still opened as read-only.

For reference, below is what those commands actually mean and do:

* **:w** : Write
* **!sudo** : Invoke a shell with the _sudo_ command
* **tee** : the output of the write command above
* **%** : the current file path

That's it for this quite short first post. I hope this trick proves useful, as it saved my day earlier today :) Any comment is obviously more than welcome.



