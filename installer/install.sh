#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "==> Directorio del repo: $DOTFILES_DIR"

# -----------------------------------------------------------
# 1. Paquetes base de pacman
# -----------------------------------------------------------
if [ -f "$DOTFILES_DIR/packages/pacman.txt" ]; then
    echo "==> Instalando paquetes de pacman..."
    sudo pacman -S --needed - < "$DOTFILES_DIR/packages/pacman.txt" || true
fi

# -----------------------------------------------------------
# 2. Instalar paru si no existe
# -----------------------------------------------------------
if ! command -v paru &> /dev/null; then
    echo "==> paru no encontrado, instalando..."
    sudo pacman -S --needed base-devel git
    tmp_dir=$(mktemp -d)
    git clone https://aur.archlinux.org/paru.git "$tmp_dir/paru"
    (cd "$tmp_dir/paru" && makepkg -si --noconfirm)
    rm -rf "$tmp_dir"
fi

# -----------------------------------------------------------
# 3. Instalar el rice base "illogical impulse" (dots-hyprland)
# -----------------------------------------------------------
DOTS_HYPRLAND_DIR="$HOME/.cache/dots-hyprland"
if ! command -v Hyprland &> /dev/null; then
    echo "==> Instalando dots-hyprland (illogical impulse)..."
    if [ ! -d "$DOTS_HYPRLAND_DIR" ]; then
        git clone --recursive https://github.com/end-4/dots-hyprland "$DOTS_HYPRLAND_DIR"
    fi
    (cd "$DOTS_HYPRLAND_DIR" && ./setup install)
else
    echo "==> Hyprland ya está instalado, saltando dots-hyprland."
fi

# -----------------------------------------------------------
# 3.5. Instalar SDDM + tema SilentSDDM
# -----------------------------------------------------------
if ! command -v sddm &> /dev/null; then
    echo "==> Instalando SDDM y dependencias del tema..."
    sudo pacman -S --needed sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg qt6-imageformats
fi

SILENTSDDM_DIR="$HOME/.cache/SilentSDDM"
if [ ! -d "/usr/share/sddm/themes/silent" ]; then
    echo "==> Instalando tema SilentSDDM..."
    if [ ! -d "$SILENTSDDM_DIR" ]; then
        git clone -b main --depth=1 https://github.com/uiriansan/SilentSDDM "$SILENTSDDM_DIR"
    fi
    (cd "$SILENTSDDM_DIR" && ./install.sh)
    if [ -f "$DOTFILES_DIR/system/sddm.conf" ]; then
        sudo cp "$DOTFILES_DIR/system/sddm.conf" /etc/sddm.conf
    fi
    sudo systemctl enable sddm
else
    echo "==> Tema SilentSDDM ya está instalado, saltando."
fi

# -----------------------------------------------------------
# 4. Paquetes AUR restantes (excluyendo illogical-impulse-*)
# -----------------------------------------------------------
if [ -f "$DOTFILES_DIR/packages/aur.txt" ]; then
    echo "==> Instalando paquetes AUR restantes..."
    grep -v "^illogical-impulse-" "$DOTFILES_DIR/packages/aur.txt" > /tmp/aur_filtered.txt || true
    if [ -s /tmp/aur_filtered.txt ]; then
        paru -S --needed - < /tmp/aur_filtered.txt || true
    fi
    rm -f /tmp/aur_filtered.txt
fi

# -----------------------------------------------------------
# 5. Flatpak
# -----------------------------------------------------------
if [ -f "$DOTFILES_DIR/packages/flatpak.txt" ] && [ -s "$DOTFILES_DIR/packages/flatpak.txt" ]; then
    echo "==> Configurando Flathub..."
    sudo pacman -S --needed flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    echo "==> Instalando paquetes Flatpak..."
    while read -r pkg; do
        if [ -n "$pkg" ]; then
            flatpak install -y flathub "$pkg" || true
        fi
    done < "$DOTFILES_DIR/packages/flatpak.txt"
fi

# -----------------------------------------------------------
# 6. Stow: enlazar tus dotfiles personalizados
# -----------------------------------------------------------
echo "==> Instalando Stow..."
sudo pacman -S --needed stow

echo "==> Enlazando dotfiles con Stow..."
cd "$DOTFILES_DIR/dotfiles"
for package in */; do
    package_name="${package%/}"
    echo "    - Enlazando $package_name"
    stow --adopt -t "$HOME" "$package_name" 2>/dev/null || stow -t "$HOME" "$package_name"
done
cd "$DOTFILES_DIR"

# -----------------------------------------------------------
# 7. Configurar fish como shell por defecto
# -----------------------------------------------------------
if command -v fish &> /dev/null && [ "$SHELL" != "$(command -v fish)" ]; then
    echo "==> Configurando fish como shell por defecto..."
    sudo chsh -s "$(command -v fish)" "$USER" || true
fi

# -----------------------------------------------------------
# 8. Wallpapers, temas y fuentes (solo si tienen contenido)
# -----------------------------------------------------------
copy_if_not_empty() {
    local src="$1"
    local dest="$2"
    if [ -d "$src" ] && [ "$(ls -A "$src" 2>/dev/null)" ]; then
        mkdir -p "$dest"
        cp -r "$src/." "$dest/"
    fi
}

copy_if_not_empty "$DOTFILES_DIR/wallpapers" "$HOME/Pictures/wallpapers"
copy_if_not_empty "$DOTFILES_DIR/themes" "$HOME/.local/share/themes"
copy_if_not_empty "$DOTFILES_DIR/fonts" "$HOME/.local/share/fonts"

if [ -d "$HOME/.local/share/fonts" ] && [ "$(ls -A "$HOME/.local/share/fonts" 2>/dev/null)" ]; then
    fc-cache -f
fi

echo ""
echo "✅ Migración completa. Reinicia la sesión para aplicar todo."
