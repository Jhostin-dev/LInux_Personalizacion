#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "==> Directorio del repo: $DOTFILES_DIR"

# 1. Paquetes de pacman
if [ -f "$DOTFILES_DIR/packages/pacman.txt" ]; then
    echo "==> Instalando paquetes de pacman..."
    sudo pacman -S --needed - < "$DOTFILES_DIR/packages/pacman.txt"
fi

# 2. Instalar paru si no existe
if ! command -v paru &> /dev/null; then
    echo "==> paru no encontrado, instalando..."
    sudo pacman -S --needed base-devel git
    tmp_dir=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$tmp_dir/paru"
    (cd "$tmp_dir/paru" && makepkg -si --noconfirm)
    rm -rf "$tmp_dir"
fi

# 3. Paquetes AUR
if [ -f "$DOTFILES_DIR/packages/aur.txt" ]; then
    echo "==> Instalando paquetes AUR..."
    paru -S --needed - < "$DOTFILES_DIR/packages/aur.txt"
fi

# 4. Flatpak
if [ -f "$DOTFILES_DIR/packages/flatpak.txt" ]; then
    echo "==> Configurando Flathub..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    echo "==> Instalando paquetes Flatpak..."
    while read -r pkg; do
        if [ -n "$pkg" ]; then
            flatpak install -y flathub "$pkg"
        fi
    done < "$DOTFILES_DIR/packages/flatpak.txt"
fi

# 5. Stow (enlazar dotfiles)
echo "==> Instalando Stow..."
sudo pacman -S --needed stow

echo "==> Enlazando dotfiles con Stow..."
cd "$DOTFILES_DIR/dotfiles"
for package in */; do
    package_name="${package%/}"
    echo "    - Enlazando $package_name"
    stow -t "$HOME" "$package_name"
done

# 6. Wallpapers, temas y fuentes
if [ -d "$DOTFILES_DIR/wallpapers" ] && [ "$(ls -A "$DOTFILES_DIR/wallpapers" 2>/dev/null)" ]; then
    mkdir -p "$HOME/Pictures/wallpapers"
    cp -r "$DOTFILES_DIR/wallpapers/." "$HOME/Pictures/wallpapers/"
fi

if [ -d "$DOTFILES_DIR/themes" ] && [ "$(ls -A "$DOTFILES_DIR/themes" 2>/dev/null)" ]; then
    mkdir -p "$HOME/.local/share/themes"
    cp -r "$DOTFILES_DIR/themes/." "$HOME/.local/share/themes/"
fi

if [ -d "$DOTFILES_DIR/fonts" ] && [ "$(ls -A "$DOTFILES_DIR/fonts" 2>/dev/null)" ]; then
    mkdir -p "$HOME/.local/share/fonts"
    cp -r "$DOTFILES_DIR/fonts/." "$HOME/.local/share/fonts/"
    fc-cache -f
fi

echo ""
echo "Migracion completa. Reinicia sesion o Hyprland para aplicar todo."
