# Building your layout from source

Congratulations on taking the next step, and making use of your keyboard's open-source nature! There's so much you can do with QMK.

Here's how to get started compiling your own firmware:

1. Choose whether to build your layout against ZSA's QMK fork or mainline QMK. Using ZSA's fork means your firmware will compile easily, but it is slower to update and does not pull all the new features of mainline QMK. Mainline is the bleeding edge, but you will probably need to debug some compiler errors when setting up your layout for the first time.
2. Use the documentation at [docs.qmk.fm](https://docs.qmk.fm/) to set up your environment for building your firmware.
   - If you would like to compile against ZSA's fork, make sure to manually set the path when going through the setup: [https://github.com/zsa/qmk_firmware/](https://github.com/zsa/qmk_firmware/) (ZSA's QMK fork). Otherwise, the setup process will default to mainline QMK (qmk/qmk_firmware).
     - ZSA's QMK fork will default to the current firmware revision, but it is possible to compile against other revisions by specifying the relevant branch. You can see what firmware revision a layout was compiled against in Oryx by looking at the badge at the top right, e.g. "firmware v24.0", "firmware v23.0" etc. 3. Create a folder with a simple name and no spaces for your layout inside the qmk_firmware/keyboards/zsa/ergodox_ez/m32u4/keymaps/ folder.
   - Optionally, you can instead use an external userspace: https://docs.qmk.fm/newbs_external_userspace
3. Copy the contents of the \*\_source folder (in the .zip you downloaded from Oryx) into this folder.
4. Make sure you've set up your environment for compiling per the [QMK docs](https://docs.qmk.fm/#/newbs_getting_started?id=set-up-your-environment).
5. From your shell, make sure your working directory is qmk_firmware, then enter the command `qmk compile`. If you haven't set up a default keyboard and layout through the QMK docs, you'll need to specify these manually: `qmk compile -kb <your-keyboard> -km <your-layout-folder-name>`.
6. To flash, enter the command `qmk flash`, then put your board into bootloader mode with the reset button.

Good luck on your journey! If you would like to maintain your Oryx layout with custom QMK functionality, check out this [community-made tool to add custom QMK features to your Oryx layout](https://blog.zsa.io/oryx-custom-qmk-features/). And remember, if you get stuck, you can always get back to your [original layout](https://configure.zsa.io/ergodox-ez/layouts/wagdn/qmvNyL/0) from Oryx.
