import { readFileSync, writeFileSync, type PathOrFileDescriptor } from 'fs';

type HSL = [number, number, number];

const hslToHex = ([h, s, l]: HSL) => {
    console.log(h, s, l)
    l /= 100;
    const a = s * Math.min(l, 1 - l) / 100;
    const f = (n: number) => {
        const k = (n + h / 30) % 12;
        const color = l - a * Math.max(Math.min(k - 3, 9 - k, 1), -1);
        return Math.round(255 * color).toString(16).padStart(2, '0');
    };
    const hex = `#${f(0)}${f(8)}${f(4)}`;
    console.log(hex)
    return hex;
}

interface Config {
    themeType: HSL;
    themeName: HSL;
    background: {
        primary: HSL,
        secondary: HSL,
    },
    language: {
        type: HSL,
        operator: HSL,
        value: HSL,
        function: HSL,
        parameter: HSL,
        comment: HSL,
        constant: HSL,
        entity: HSL,
        invalid: HSL,
        keyword: HSL,
        storage: HSL,
        string: HSL,
        support: HSL,
        variable: HSL,
    },
}

interface Theme extends ReturnType<typeof generateTheme> { }

const readConfig = (path: PathOrFileDescriptor) => {
    const file = readFileSync(path, 'utf8');
    const content = JSON.parse(file);
    return content;
}

const generateTheme = (config: Config) => {
    return {
        "type": hslToHex(config.themeType),
        "name": hslToHex(config.themeName),
        "colors": {
            "activityBar.background": hslToHex(config.background.primary),
            "editor.background": hslToHex(config.background.primary),
            "editorGroupHeader.tabsBackground": hslToHex(config.background.secondary) + "33",
            "editorWidget.background": hslToHex(config.background.secondary),
            "input.background": hslToHex(config.background.primary),
            "panel.background": hslToHex(config.background.secondary),
            "panel.border": hslToHex(config.background.primary),
            "sideBar.background": hslToHex(config.background.secondary),
            "statusBar.background": hslToHex(config.background.secondary),
            "terminal.background": hslToHex(config.background.primary),
            "tab.border": hslToHex(config.background.primary),
            "tab.inactiveBackground": hslToHex(config.background.secondary),
            "titleBar.activeBackground": hslToHex(config.background.primary),
            "titleBar.inactiveBackground": hslToHex(config.background.secondary),
            "widget.shadow": hslToHex(config.background.primary) + "33",
        },
        "tokenColors": [
            {
                "name": "Comment",
                "scope": "comment",
                "settings": {
                    "foreground": hslToHex(config.language.comment),
                }
            },
            {
                "name": "Constant",
                "scope": "constant",
                "settings": {
                    "foreground": hslToHex(config.language.value),
                }
            },
            {
                "name": "Entity",
                "scope": "entity",
                "settings": {
                    "foreground": hslToHex(config.language.type),
                }
            },
            {
                "name": "Entity Name Function",
                "scope": "entity.name.function",
                "settings": {
                    "foreground": hslToHex(config.language.function),
                }
            },
            {
                "name": "Invalid",
                "scope": "invalid",
                "settings": {
                    "foreground": hslToHex(config.language.invalid),
                }
            },
            {
                "name": "Keyword Operator",
                "scope": "keyword.operator",
                "settings": {
                    "foreground": hslToHex(config.language.operator),
                }
            },
            {
                "name": "String",
                "scope": "string",
                "settings": {
                    "foreground": hslToHex(config.language.value),
                }
            },
            {
                "name": "Support",
                "scope": "support",
                "settings": {
                    "foreground": hslToHex(config.language.support),
                }
            },
            {
                "name": "Variable Parameter",
                "scope": "variable.parameter",
                "settings": {
                    "foreground": hslToHex(config.language.parameter),
                }
            }
        ]
    };
}

const writeTheme = (path: PathOrFileDescriptor, theme: Theme) => {
    const content = JSON.stringify(theme, null, 2)
    writeFileSync(path, content);
}

const main = () => {
    const args = process.argv.slice(2);

    if (args.length < 2) {
        console.error("Please provide both an input path and an output path.");
        process.exit(1);
    }

    const [inputPath, outputPath] = args;

    const cfg = readConfig(inputPath);
    const theme = generateTheme(cfg);
    writeTheme(outputPath, theme);
}

main();
