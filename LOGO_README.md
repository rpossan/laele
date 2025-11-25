# Logo e Favicon - LSA eScale

Este documento descreve os arquivos de logo e favicon criados para a aplicação LSA eScale.

## Arquivos Criados

### SVG (Vetoriais - Recomendados)
- **`public/icon.svg`** - Favicon em formato SVG (32x32px)
- **`public/logo-icon.svg`** - Ícone do logo (64x64px) - usado no header
- **`public/logo.svg`** - Logo completo com texto (200x60px)

### PNG (Raster - Para compatibilidade)
Os arquivos PNG devem ser gerados a partir dos SVGs. Use o script fornecido ou ferramentas online.

## Como Gerar PNGs

### Opção 1: Script Automático (Recomendado)

Execute o script fornecido:

```bash
./scripts/generate_favicons.sh
```

Este script irá gerar:
- `favicon-16x16.png`
- `favicon-32x32.png`
- `favicon-48x48.png`
- `icon.png` (64x64px)
- `apple-touch-icon.png` (180x180px)

**Requisitos:**
- ImageMagick (`brew install imagemagick` ou `apt-get install imagemagick`)
- OU Inkscape (`brew install inkscape` ou `apt-get install inkscape`)

### Opção 2: Ferramentas Online

Se não tiver ImageMagick ou Inkscape instalados, use:

1. **CloudConvert**: https://cloudconvert.com/svg-to-png
2. **Convertio**: https://convertio.co/svg-png/
3. **SVG to PNG**: https://svgtopng.com/

**Tamanhos necessários:**
- 16x16px (favicon-16x16.png)
- 32x32px (favicon-32x32.png)
- 48x48px (favicon-48x48.png)
- 64x64px (icon.png)
- 180x180px (apple-touch-icon.png)

## Design

### Cores
- **Gradiente Principal**: Indigo (#4f46e5) → Purple (#7c3aed)
- **Fundo**: Branco com opacidade para elementos decorativos

### Elementos Visuais
- **Forma Principal**: Representa um documento/lead
- **Linhas Internas**: Representam dados/informações
- **Gráfico**: Indicador de analytics/inteligência

### Uso no Código

O logo é usado no header da aplicação:

```erb
<img src="/logo-icon.svg" alt="LSA eScale" class="h-10 w-10" />
```

O favicon é referenciado no `<head>` do layout:

```erb
<link rel="icon" href="/icon.svg" type="image/svg+xml">
<link rel="icon" href="/icon.png" type="image/png" sizes="64x64">
```

## Personalização

Para personalizar as cores, edite os arquivos SVG e altere:
- `#4f46e5` (indigo-600) - cor inicial do gradiente
- `#7c3aed` (purple-600) - cor final do gradiente

Essas cores devem corresponder ao tema da aplicação definido no Tailwind CSS.

