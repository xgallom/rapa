# rapa (RAndom PAssword)

`rapa` is a lightweight, secure utility designed to generate high-entropy passwords and manage your 
clipboard safely. It ensures that your secrets are handled with minimal exposure.

*Note: `rapa` utilizes the system `pbcopy` utility. It is currently only intended for use on macOS.*


## Usage

You can run `rapa` directly from your terminal.

| Command | Description |
| --- | --- |
| `rapa` | Generates a new secure password and copies it to your clipboard. |
| `rapa generate` | Performs the same action as running `rapa`. |
| `rapa clear` | Securely wipes your system clipboard buffer. |
| `rapa help` | Displays this help message. |


### Security Considerations: Clipboard History

When you run `rapa`, the generated password is piped directly to the macOS system clipboard via 
`pbcopy`. While the `rapa clear` command securely clears the current clipboard buffer,it **cannot** 
erase data that has already been captured by the OS-level clipboard history.

Starting with macOS 26 ("Tahoe"), Apple integrated a native clipboard history feature accessible
via Spotlight (`Cmd + 4`). If this feature is enabled, every password generated and copied by `rapa`
will be stored in plaintext within the OS history logs for the duration configured in your system
settings.

To ensure your generated secrets do not linger in your system's memory, it is highly recommended to
disable this feature on the machine where `rapa` is used:

1. Open **System Settings**.
2. Navigate to **Spotlight**.
3. Scroll bellow Search Results and other settings and press **Clear Clipboard History**.
4. Right above, disable **Results from Clipboard**.

For maximum operational security, always run `rapa clear` immediately after pasting your generated
password to wipe the active buffer.


## Building from Source

`rapa` is written in Zig and requires the Zig compiler to build.

1. **Install Zig:** Ensure you have the Zig compiler installed ([ziglang.org](https://ziglang.org/)).
2. **Clone the repository:**

```bash
git clone https://github.com/xgallom/rapa.git
cd rapa

```

3. **Build:**

```bash
zig build

```

The executable will be generated in the `zig-out/bin` directory.


## Obtaining Releases

Pre-built binaries are available in [Releases](https://github.com/xgallom/rapa/releases/latest). 
You can download the binary for your architecture, extract it and move it to a directory in your
`$PATH` (e.g., `/usr/local/bin`):

```bash
sudo cp ./rapa /usr/local/bin/

```


## Running

Once installed, simply type `rapa` in your terminal to generate a password. The password will be
automatically copied to your system clipboard, allowing you to paste it into any web browser or
application. To keep your system secure, don't forget to run `rapa clear` whenever you are
finished pasting your credentials.


## License

This project is licensed under the MIT License. See the [license file](LICENSE.txt) for details.


