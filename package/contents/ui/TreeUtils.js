.pragma library

// Node: { name, icon, type: "script"|"file"|"drawer", command, path, terminal,
//         color, bg, children: [] }

function newNode(type, name) {
    return {
        name: name || "",
        icon: "",
        type: type,
        command: "",
        path: "",
        terminal: false,
        color: "",
        bg: "",
        children: []
    };
}

function parse(json) {
    try {
        var t = JSON.parse(json);
        return Array.isArray(t) ? t : [];
    } catch (e) {
        return [];
    }
}

function exportJson(tree) {
    return JSON.stringify({ format: "scriptlauncher", version: 1, items: tree }, null, 2);
}

// Returns the list of nodes from an exported file (or a bare array), or null when invalid.
function parseImport(text) {
    try {
        var data = JSON.parse(text);
        var items = Array.isArray(data) ? data : (data && Array.isArray(data.items) ? data.items : null);
        if (!items)
            return null;
        var check = function (list) {
            return list.every(function (n) {
                return n && typeof n === "object" && ["script", "file", "drawer"].indexOf(n.type) >= 0 &&
                       (!n.children || (Array.isArray(n.children) && check(n.children)));
            });
        };
        return check(items) ? items : null;
    } catch (e) {
        return null;
    }
}

function flatten(tree, depth, out) {
    out = out || [];
    depth = depth || 0;
    for (var i = 0; i < tree.length; ++i) {
        var n = Object.assign(newNode(tree[i].type || "script"), tree[i]);
        var kids = n.children || [];
        n.children = [];
        n.depth = depth;
        out.push(n);
        if (n.type === "drawer")
            flatten(kids, depth + 1, out);
    }
    return out;
}

// Clamps depths so that only drawers can have children.
function normalize(flat) {
    for (var i = 0; i < flat.length; ++i) {
        var max = 0;
        if (i > 0)
            max = flat[i - 1].type === "drawer" ? flat[i - 1].depth + 1 : flat[i - 1].depth;
        flat[i].depth = Math.max(0, Math.min(flat[i].depth, max));
    }
    return flat;
}

function unflatten(flat) {
    var root = [];
    var stack = [root];
    normalize(flat);
    for (var i = 0; i < flat.length; ++i) {
        var n = Object.assign({}, flat[i]);
        var d = n.depth;
        delete n.depth;
        n.children = [];
        stack.length = d + 1;
        stack[d].push(n);
        stack[d + 1] = n.children;
    }
    return root;
}

function serialize(flat) {
    return JSON.stringify(unflatten(flat));
}

function blockEnd(flat, from) {
    var d = flat[from].depth;
    var e = from + 1;
    while (e < flat.length && flat[e].depth > d)
        e++;
    return e; // exclusive
}

// Moves the subtree starting at `from` so that it is inserted before original
// index `k`, with the head at `newDepth`. Returns a new array.
function moveBlock(flat, from, k, newDepth) {
    var end = blockEnd(flat, from);
    var len = end - from;
    if (k > from && k <= end)
        k = from;
    else if (k > end)
        k -= len;
    var block = flat.slice(from, end).map(function (n) { return Object.assign({}, n); });
    var rest = flat.slice(0, from).concat(flat.slice(end));
    var max = 0;
    if (k > 0)
        max = rest[k - 1].type === "drawer" ? rest[k - 1].depth + 1 : rest[k - 1].depth;
    newDepth = Math.max(0, Math.min(newDepth, max));
    var shift = newDepth - block[0].depth;
    block.forEach(function (n) { n.depth += shift; });
    var res = rest.slice(0, k).concat(block, rest.slice(k));
    return { items: normalize(res), index: k };
}

function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

function expandHome(p) {
    if (p === "~")
        return "\"$HOME\"";
    if (p.indexOf("~/") === 0)
        return "\"$HOME\"" + shellQuote(p.substring(1));
    return shellQuote(p);
}

function isEmpty(node) {
    return (node.type === "script" && !String(node.command || "").trim()) ||
           (node.type === "file" && !String(node.path || "").trim());
}

function notifyCommand(title, text, icon, appName) {
    return "notify-send -a " + shellQuote(appName) + " -i " + shellQuote(icon) +
           " " + shellQuote(title) + " " + shellQuote(text) + " >/dev/null 2>&1 </dev/null";
}

// Shell snippet defining $t: the terminal command including its "run command" flag.
// An empty custom command means the KDE default terminal (konsole as a fallback).
function terminalSnippet(custom) {
    custom = String(custom || "").trim();
    if (custom)
        return "t=" + shellQuote(custom) + "; ";
    return "t=$(kreadconfig6 --file kdeglobals --group General --key TerminalApplication 2>/dev/null); " +
           "[ -n \"$t\" ] || t=konsole; " +
           "case \"${t##*/}\" in gnome-terminal|ptyxis|kgx) t=\"$t --\";; kitty) ;; wezterm) t=\"$t start --\";; *) t=\"$t -e\";; esac; ";
}

// Detached command line for the "executable" data engine.
// opts: { terminal: custom terminal command, closeMessage: text shown after a terminal run }
function launchCommand(node, opts) {
    opts = opts || {};
    var detach = " >/dev/null 2>&1 </dev/null";
    var inTerm = node.terminal === true;
    var wait = "; printf '\\n%s' " + shellQuote(opts.closeMessage || "Press Enter to close...") + "; read _";
    if (node.type === "script") {
        // The script is saved to a temp file and run through its shebang (bash when absent).
        var body = String(node.command).replace(/\r\n?/g, "\n");
        var hasShebang = body.indexOf("#!") === 0;
        var run = hasShebang ? "\"$1\"" : "bash \"$1\"";
        var prep = "f=$(mktemp \"${XDG_RUNTIME_DIR:-/tmp}/scriptlauncher.XXXXXX\") && " +
                   "printf '%s\\n' " + shellQuote(body) + " > \"$f\" && chmod 700 \"$f\" && cd \"$HOME\" && ";
        if (inTerm)
            return prep + terminalSnippet(opts.terminal) +
                   "setsid -f $t sh -c " + shellQuote(run + "; rm -f \"$1\"" + wait) + " sh \"$f\"" + detach;
        return prep + "setsid -f sh -c " + shellQuote(run + "; rm -f \"$1\"") + " sh \"$f\"" + detach;
    }
    if (node.type === "file") {
        var f = expandHome(node.path);
        var start = "f=" + f + "; cd \"$HOME\"; ";
        if (inTerm)
            return start + terminalSnippet(opts.terminal) +
                   "if [ -f \"$f\" ] && [ -x \"$f\" ]; then setsid -f $t sh -c " + shellQuote("\"$1\"" + wait) + " sh \"$f\"" + detach +
                   "; else setsid -f xdg-open \"$f\"" + detach + "; fi";
        return start + "if [ -f \"$f\" ] && [ -x \"$f\" ]; then " +
               "setsid -f \"$f\"" + detach + "; else setsid -f xdg-open \"$f\"" + detach + "; fi";
    }
    return "";
}

function defaultIcon(node) {
    if (node.icon)
        return node.icon;
    return node.type === "drawer" ? "folder" : (node.type === "file" ? "application-x-executable" : "utilities-terminal");
}
