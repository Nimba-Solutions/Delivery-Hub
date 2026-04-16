
/* === LWS-safe Tailwind v4 token defaults (replaces stripped @property regs) === */
:root, .nga-root {
  --spacing: 0.25rem;
  --color-white: #ffffff;
  --color-black: #000000;
  --container-md: 28rem;
  --blur-sm: 8px;
  --radius-sm: 0.125rem;
  --radius-md: 0.375rem;
  --radius-lg: 0.5rem;
  --radius-xl: 0.75rem;
  --text-xs: 0.75rem;       --text-xs--line-height: calc(1 / 0.75);
  --text-sm: 0.875rem;      --text-sm--line-height: calc(1.25 / 0.875);
  --text-base: 1rem;        --text-base--line-height: 1.5;
  --text-lg: 1.125rem;      --text-lg--line-height: calc(1.75 / 1.125);
  --text-xl: 1.25rem;       --text-xl--line-height: calc(1.75 / 1.25);
  --text-2xl: 1.5rem;       --text-2xl--line-height: calc(2 / 1.5);
  --font-weight-normal: 400;
  --font-weight-medium: 500;
  --font-weight-semibold: 600;
  --font-weight-bold: 700;
  /* --font-geist-sans / --font-geist-mono intentionally NOT set here so the
     host page's :root declaration (globals.css loads Geist on cloudnimbusllc.com)
     wins. For Salesforce/LWS and standalone HTML where Geist isn't loaded, the
     :where(:root) fallback block further down supplies a system-font default. */
  --tracking-tighter: -0.05em;
  --tracking-tight: -0.025em;
  --tracking-normal: 0em;
  --tracking-wide: 0.025em;
  --tracking-wider: 0.05em;
  --tracking-widest: 0.1em;
  --leading-tight: 1.25;
  --leading-snug: 1.375;
  --leading-normal: 1.5;
  --leading-relaxed: 1.625;
  --leading-loose: 2;
  --default-transition-duration: 150ms;
  --default-transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
  --ease-linear: linear;
  --ease-in: cubic-bezier(0.4, 0, 1, 1);
  --ease-out: cubic-bezier(0, 0, 0.2, 1);
  --ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);
  --tw-border-style: solid;
  --tw-divide-y-reverse: 0;
  --tw-translate-x: 0; --tw-translate-y: 0; --tw-rotate: 0;
  --tw-skew-x: 0; --tw-skew-y: 0; --tw-scale-x: 1; --tw-scale-y: 1;
  --tw-pan-x: ; --tw-pan-y: ; --tw-pinch-zoom: ;
  --tw-scroll-snap-strictness: proximity;
  --tw-ordinal: ; --tw-slashed-zero: ; --tw-numeric-figure: ; --tw-numeric-spacing: ; --tw-numeric-fraction: ;
  --tw-ring-inset: ; --tw-ring-offset-width: 0px; --tw-ring-offset-color: #fff;
  --tw-ring-color: rgba(59, 130, 246, 0.5); --tw-ring-offset-shadow: 0 0 #0000;
  --tw-ring-shadow: 0 0 #0000; --tw-shadow: 0 0 #0000; --tw-shadow-colored: 0 0 #0000;
  --tw-blur: ; --tw-brightness: ; --tw-contrast: ; --tw-grayscale: ; --tw-hue-rotate: ; --tw-invert: ;
  --tw-saturate: ; --tw-sepia: ; --tw-drop-shadow: ;
  --tw-backdrop-blur: ; --tw-backdrop-brightness: ; --tw-backdrop-contrast: ;
  --tw-backdrop-grayscale: ; --tw-backdrop-hue-rotate: ; --tw-backdrop-invert: ;
  --tw-backdrop-opacity: ; --tw-backdrop-saturate: ; --tw-backdrop-sepia: ;
  --tw-content: '';
}

/* Semantic chrome class layout fallbacks (in case nga-* class layouts depend on Tailwind specificity) */
.nga-root { display: flex; flex-direction: column; height: 100%; width: 100%; overflow: hidden; }
/* Fullscreen escape — covers Salesforce header/nav/footer with one click */
.nga-fullscreen { position: fixed !important; inset: 0 !important; z-index: 9999 !important; width: 100vw !important; height: 100vh !important; background: #f8fafc !important; }
.nga-titlebar { display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap; padding: 6px 12px; background: #fff; border-bottom: 1px solid #e2e8f0; flex-shrink: 0; }
.nga-filterbar { display: block; padding: 6px 12px; background: #fff; border-bottom: 1px solid #f1f5f9; flex-shrink: 0; }
.nga-zoombar { display: flex; align-items: center; gap: 0.5rem; }
.nga-stats { padding: 12px; background: #fff; border-bottom: 1px solid #f1f5f9; flex-shrink: 0; }
.nga-sidebar { display: flex; flex-direction: column; height: 100%; background: #fff; border-right: 1px solid #e2e8f0; }
.nga-content-outer { flex: 1 1 auto; display: flex; overflow: hidden; min-width: 0; min-height: 0; }
.nga-content { flex: 1 1 auto; position: relative; min-width: 0; min-height: 0; }
.nga-detail { position: fixed; z-index: 9999; background: #fff; border: 2px solid #e2e8f0; border-radius: 12px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.25); overflow: hidden; }
.nga-audit { padding: 8px 12px; background: rgba(253, 244, 255, 0.6); border-bottom: 1px solid #f5d0fe; }
.nga-hrswkstrip { display: flex; align-items: flex-end; gap: 4px; padding: 6px 12px; background: #f8fafc; border-bottom: 1px solid #e2e8f0; overflow-x: auto; flex-shrink: 0; }

/* === nimbus-gantt cloudnimbus template.css ===
 * Extracted from cloudnimbusllc.com Next.js build output (Tailwind v4).
 * Contains the reset + theme variables + only the utilities used by
 * DeliveryTimelineV5 and gantt-demo components (see v10-used-tailwind-classes.txt).
 * Plus .ng-* overrides for the gantt library. Ship alongside @nimbus-gantt/app
 * for pixel parity between v10 (Next.js) and Salesforce deployments.
 * No Tailwind runtime dependency. */

@media (prefers-reduced-motion:reduce){.cloud,.cloud:before,.cloud:after{animation:none!important}}







































































@supports (((-webkit-hyphens:none)) and (not (margin-trim:inline))) or ((-moz-orient:inline) and (not (color:rgb(from red r g b)))){*,:before,:after,::backdrop{--tw-translate-x:0;--tw-translate-y:0;--tw-translate-z:0;--tw-scale-x:1;--tw-scale-y:1;--tw-scale-z:1;--tw-rotate-x:initial;--tw-rotate-y:initial;--tw-rotate-z:initial;--tw-skew-x:initial;--tw-skew-y:initial;--tw-space-y-reverse:0;--tw-divide-x-reverse:0;--tw-border-style:solid;--tw-divide-y-reverse:0;--tw-gradient-position:initial;--tw-gradient-from:#0000;--tw-gradient-via:#0000;--tw-gradient-to:#0000;--tw-gradient-stops:initial;--tw-gradient-via-stops:initial;--tw-gradient-from-position:0%;--tw-gradient-via-position:50%;--tw-gradient-to-position:100%;--tw-leading:initial;--tw-font-weight:initial;--tw-tracking:initial;--tw-ordinal:initial;--tw-slashed-zero:initial;--tw-numeric-figure:initial;--tw-numeric-spacing:initial;--tw-numeric-fraction:initial;--tw-shadow:0 0 #0000;--tw-shadow-color:initial;--tw-shadow-alpha:100%;--tw-inset-shadow:0 0 #0000;--tw-inset-shadow-color:initial;--tw-inset-shadow-alpha:100%;--tw-ring-color:initial;--tw-ring-shadow:0 0 #0000;--tw-inset-ring-color:initial;--tw-inset-ring-shadow:0 0 #0000;--tw-ring-inset:initial;--tw-ring-offset-width:0px;--tw-ring-offset-color:#fff;--tw-ring-offset-shadow:0 0 #0000;--tw-outline-style:solid;--tw-blur:initial;--tw-brightness:initial;--tw-contrast:initial;--tw-grayscale:initial;--tw-hue-rotate:initial;--tw-invert:initial;--tw-opacity:initial;--tw-saturate:initial;--tw-sepia:initial;--tw-drop-shadow:initial;--tw-drop-shadow-color:initial;--tw-drop-shadow-alpha:100%;--tw-drop-shadow-size:initial;--tw-backdrop-blur:initial;--tw-backdrop-brightness:initial;--tw-backdrop-contrast:initial;--tw-backdrop-grayscale:initial;--tw-backdrop-hue-rotate:initial;--tw-backdrop-invert:initial;--tw-backdrop-opacity:initial;--tw-backdrop-saturate:initial;--tw-backdrop-sepia:initial;--tw-duration:initial;--tw-ease:initial}}

:root,:host{--color-red-50:#fef2f2;--color-red-500:#fb2c36;--color-red-600:#e40014;--color-orange-50:#fff7ed;--color-orange-600:#f05100;--color-amber-50:#fffbeb;--color-amber-100:#fef3c6;--color-amber-300:#ffd236;--color-amber-500:#f99c00;--color-amber-600:#dd7400;--color-amber-700:#b75000;--color-amber-800:#953d00;--color-emerald-50:#ecfdf5;--color-emerald-100:#d0fae5;--color-emerald-200:#a4f4cf;--color-emerald-500:#00bb7f;--color-emerald-600:#009767;--color-emerald-700:#007956;--color-emerald-800:#005f46;--color-sky-50:#f0f9ff;--color-sky-100:#dff2fe;--color-sky-600:#0084cc;--color-sky-700:#0069a4;--color-blue-50:#eff6ff;--color-blue-100:#dbeafe;--color-blue-200:#bedbff;--color-blue-300:#90c5ff;--color-blue-400:#54a2ff;--color-blue-500:#3080ff;--color-blue-600:#155dfc;--color-blue-700:#1447e6;--color-blue-800:#193cb8;--color-indigo-50:#eef2ff;--color-indigo-100:#e0e7ff;--color-indigo-200:#c7d2ff;--color-indigo-300:#a4b3ff;--color-indigo-400:#7d87ff;--color-indigo-500:#625fff;--color-indigo-600:#4f39f6;--color-indigo-700:#432dd7;--color-violet-50:#f5f3ff;--color-violet-200:#ddd6ff;--color-violet-300:#c4b4ff;--color-violet-600:#7f22fe;--color-purple-50:#faf5ff;--color-purple-100:#f3e8ff;--color-purple-200:#e9d5ff;--color-purple-300:#d9b3ff;--color-purple-500:#ac4bff;--color-purple-600:#9810fa;--color-purple-700:#8200da;--color-purple-800:#6e11b0;--color-fuchsia-50:#fdf4ff;--color-fuchsia-200:#f6cfff;--color-fuchsia-500:#e12afb;--color-fuchsia-600:#c600db;--color-fuchsia-700:#a600b5;--color-rose-50:#fff1f2;--color-rose-100:#ffe4e6;--color-rose-200:#ffccd3;--color-rose-300:#ffa2ae;--color-rose-400:#ff667f;--color-rose-500:#ff2357;--color-rose-600:#e70044;--color-rose-700:#c20039;--color-rose-800:#a30037;--color-slate-50:#f8fafc;--color-slate-100:#f1f5f9;--color-slate-200:#e2e8f0;--color-slate-300:#cad5e2;--color-slate-400:#90a1b9;--color-slate-500:#62748e;--color-slate-600:#45556c;--color-slate-700:#314158;--color-slate-800:#1d293d;--color-slate-900:#0f172b;--color-white:#fff;--spacing:.25rem;--container-md:28rem;--container-2xl:42rem;--container-3xl:48rem;--container-4xl:56rem;--text-xs:.75rem;--text-xs--line-height:calc(1/.75);--text-sm:.875rem;--text-sm--line-height:calc(1.25/.875);--text-lg:1.125rem;--text-lg--line-height:calc(1.75/1.125);--text-xl:1.25rem;--text-xl--line-height:calc(1.75/1.25);--font-weight-normal:400;--font-weight-medium:500;--font-weight-semibold:600;--font-weight-bold:700;--tracking-wide:.025em;--tracking-wider:.05em;--leading-relaxed:1.625;--radius-sm:.25rem;--radius-md:.375rem;--radius-lg:.5rem;--radius-xl:.75rem;--ease-in-out:cubic-bezier(.4,0,.2,1);--blur-sm:8px;--default-transition-duration:.15s;--default-transition-timing-function:cubic-bezier(.4,0,.2,1);--default-font-family:var(--font-geist-sans);}

*,:after,:before,::backdrop{box-sizing:border-box;border:0 solid;margin:0;padding:0}::file-selector-button{box-sizing:border-box;border:0 solid;margin:0;padding:0}html,:host{-webkit-text-size-adjust:100%;tab-size:4;line-height:1.5;font-family:var(--default-font-family,ui-sans-serif,system-ui,sans-serif,"Apple Color Emoji","Segoe UI Emoji","Segoe UI Symbol","Noto Color Emoji");font-feature-settings:var(--default-font-feature-settings,normal);font-variation-settings:var(--default-font-variation-settings,normal);-webkit-tap-highlight-color:transparent}hr{height:0;color:inherit;border-top-width:1px}abbr:where([title]){-webkit-text-decoration:underline dotted;text-decoration:underline dotted}h1,h2,h3,h4,h5,h6{font-size:inherit;font-weight:inherit}a{color:inherit;-webkit-text-decoration:inherit;-webkit-text-decoration:inherit;-webkit-text-decoration:inherit;-webkit-text-decoration:inherit;text-decoration:inherit}b,strong{font-weight:bolder}code,kbd,samp,pre{font-family:var(--default-mono-font-family,ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,"Liberation Mono","Courier New",monospace);font-feature-settings:var(--default-mono-font-feature-settings,normal);font-variation-settings:var(--default-mono-font-variation-settings,normal);font-size:1em}small{font-size:80%}sub,sup{vertical-align:baseline;font-size:75%;line-height:0;position:relative}sub{bottom:-.25em}sup{top:-.5em}table{text-indent:0;border-color:inherit;border-collapse:collapse}:-moz-focusring{outline:auto}progress{vertical-align:baseline}summary{display:list-item}ol,ul,menu{list-style:none}img,svg,video,canvas,audio,iframe,embed,object{vertical-align:middle;display:block}img,video{max-width:100%;height:auto}button,input,select,optgroup,textarea{font:inherit;font-feature-settings:inherit;font-variation-settings:inherit;letter-spacing:inherit;color:inherit;opacity:1;background-color:#0000;border-radius:0}::file-selector-button{font:inherit;font-feature-settings:inherit;font-variation-settings:inherit;letter-spacing:inherit;color:inherit;opacity:1;background-color:#0000;border-radius:0}:where(select:is([multiple],[size])) optgroup{font-weight:bolder}:where(select:is([multiple],[size])) optgroup option{padding-inline-start:20px}::file-selector-button{margin-inline-end:4px}::placeholder{opacity:1}@supports (not ((-webkit-appearance:-apple-pay-button))) or (contain-intrinsic-size:1px){::placeholder{color:currentColor}@supports (color:currentColor){::placeholder{color:currentColor}}}textarea{resize:vertical}::-webkit-search-decoration{-webkit-appearance:none}::-webkit-date-and-time-value{min-height:1lh;text-align:inherit}::-webkit-datetime-edit{display:inline-flex}::-webkit-datetime-edit-fields-wrapper{padding:0}::-webkit-datetime-edit{padding-block:0}::-webkit-datetime-edit-year-field{padding-block:0}::-webkit-datetime-edit-month-field{padding-block:0}::-webkit-datetime-edit-day-field{padding-block:0}::-webkit-datetime-edit-hour-field{padding-block:0}::-webkit-datetime-edit-minute-field{padding-block:0}::-webkit-datetime-edit-second-field{padding-block:0}::-webkit-datetime-edit-millisecond-field{padding-block:0}::-webkit-datetime-edit-meridiem-field{padding-block:0}::-webkit-calendar-picker-indicator{line-height:1}:-moz-ui-invalid{box-shadow:none}button,input:where([type=button],[type=reset],[type=submit]){appearance:button}::file-selector-button{appearance:button}::-webkit-inner-spin-button{height:auto}::-webkit-outer-spin-button{height:auto}[hidden]:where(:not([hidden=until-found])){display:none!important}

.pointer-events-none{pointer-events:none}
.absolute{position:absolute}
.fixed{position:fixed}
.relative{position:relative}
.top-0{top:calc(var(--spacing)*0)}
.top-12{top:calc(var(--spacing)*12)}
.top-\[110px\]{top:110px}
.top-full{top:100%}
.right-0{right:calc(var(--spacing)*0)}
.right-2{right:calc(var(--spacing)*2)}
.right-3{right:calc(var(--spacing)*3)}
.right-4{right:calc(var(--spacing)*4)}
.left-0{left:calc(var(--spacing)*0)}
.left-2{left:calc(var(--spacing)*2)}
.z-10{z-index:10}
.z-20{z-index:20}
.z-40{z-index:40}
.z-50{z-index:50}
.z-\[60\]{z-index:60}
.z-\[100\]{z-index:100}
.z-\[110\]{z-index:110}
.z-\[9999\]{z-index:9999}
.z-\[10000\]{z-index:10000}
.mx-1{margin-inline:calc(var(--spacing)*1)}
.mx-2{margin-inline:calc(var(--spacing)*2)}
.mx-auto{margin-inline:auto}
.my-0\.5{margin-block:calc(var(--spacing)*.5)}
.my-1{margin-block:calc(var(--spacing)*1)}
.mt-0\.5{margin-top:calc(var(--spacing)*.5)}
.mt-1{margin-top:calc(var(--spacing)*1)}
.mt-1\.5{margin-top:calc(var(--spacing)*1.5)}
.mt-2{margin-top:calc(var(--spacing)*2)}
.mt-3{margin-top:calc(var(--spacing)*3)}
.mr-1{margin-right:calc(var(--spacing)*1)}
.mr-1\.5{margin-right:calc(var(--spacing)*1.5)}
.mr-2{margin-right:calc(var(--spacing)*2)}
.mb-0\.5{margin-bottom:calc(var(--spacing)*.5)}
.mb-1{margin-bottom:calc(var(--spacing)*1)}
.mb-2{margin-bottom:calc(var(--spacing)*2)}
.mb-3{margin-bottom:calc(var(--spacing)*3)}
.ml-0\.5{margin-left:calc(var(--spacing)*.5)}
.ml-1{margin-left:calc(var(--spacing)*1)}
.ml-2{margin-left:calc(var(--spacing)*2)}
.ml-auto{margin-left:auto}
.line-clamp-2{-webkit-line-clamp:2;-webkit-box-orient:vertical;display:-webkit-box;overflow:hidden}
.block{display:block}
.flex{display:flex}
.grid{display:grid}
.inline-block{display:inline-block}
.inline-flex{display:inline-flex}
.h-0\.5{height:calc(var(--spacing)*.5)}
.h-1{height:calc(var(--spacing)*1)}
.h-1\.5{height:calc(var(--spacing)*1.5)}
.h-2{height:calc(var(--spacing)*2)}
.h-2\.5{height:calc(var(--spacing)*2.5)}
.h-3{height:calc(var(--spacing)*3)}
.h-3\.5{height:calc(var(--spacing)*3.5)}
.h-full{height:100%}
.h-screen{height:100vh}
.max-h-0{max-height:calc(var(--spacing)*0)}
.max-h-\[90vh\]{max-height:90vh}
.max-h-\[120px\]{max-height:120px}
.max-h-\[400px\]{max-height:400px}
.max-h-\[600px\]{max-height:600px}
.min-h-0{min-height:calc(var(--spacing)*0)}
.w-1{width:calc(var(--spacing)*1)}
.w-2{width:calc(var(--spacing)*2)}
.w-2\.5{width:calc(var(--spacing)*2.5)}
.w-3{width:calc(var(--spacing)*3)}
.w-3\.5{width:calc(var(--spacing)*3.5)}
.w-12{width:calc(var(--spacing)*12)}
.w-14{width:calc(var(--spacing)*14)}
.w-48{width:calc(var(--spacing)*48)}
.w-56{width:calc(var(--spacing)*56)}
.w-72{width:calc(var(--spacing)*72)}
.w-\[70px\]{width:70px}
.w-\[100px\]{width:100px}
.w-\[140px\]{width:140px}
.w-full{width:100%}
.w-screen{width:100vw}
.max-w-2xl{max-width:var(--container-2xl)}
.max-w-3xl{max-width:var(--container-3xl)}
.max-w-4xl{max-width:var(--container-4xl)}
.max-w-\[90px\]{max-width:90px}
.max-w-\[280px\]{max-width:280px}
.max-w-\[320px\]{max-width:320px}
.max-w-\[1600px\]{max-width:1600px}
.max-w-full{max-width:100%}
.max-w-md{max-width:var(--container-md)}
.min-w-0{min-width:calc(var(--spacing)*0)}
.min-w-\[200px\]{min-width:200px}
.flex-1{flex:1}
.flex-shrink-0,.shrink-0{flex-shrink:0}
.cursor-col-resize{cursor:col-resize}
.cursor-grab{cursor:grab}
.cursor-not-allowed{cursor:not-allowed}
.cursor-pointer{cursor:pointer}
.resize-y{resize:vertical}
.appearance-none{appearance:none}
.grid-cols-1{grid-template-columns:repeat(1,minmax(0,1fr))}
.grid-cols-2{grid-template-columns:repeat(2,minmax(0,1fr))}
.flex-col{flex-direction:column}
.flex-wrap{flex-wrap:wrap}
.items-center{align-items:center}
.items-end{align-items:flex-end}
.items-start{align-items:flex-start}
.justify-between{justify-content:space-between}
.justify-center{justify-content:center}
.gap-0{gap:calc(var(--spacing)*0)}
.gap-0\.5{gap:calc(var(--spacing)*.5)}
.gap-1{gap:calc(var(--spacing)*1)}
.gap-1\.5{gap:calc(var(--spacing)*1.5)}
.gap-2{gap:calc(var(--spacing)*2)}
.gap-2\.5{gap:calc(var(--spacing)*2.5)}
.gap-3{gap:calc(var(--spacing)*3)}
.gap-4{gap:calc(var(--spacing)*4)}
:where(.space-y-0\.5>:not(:last-child)){--tw-space-y-reverse:0;margin-block-start:calc(calc(var(--spacing)*.5)*var(--tw-space-y-reverse));margin-block-end:calc(calc(var(--spacing)*.5)*calc(1 - var(--tw-space-y-reverse)))}
:where(.space-y-1>:not(:last-child)){--tw-space-y-reverse:0;margin-block-start:calc(calc(var(--spacing)*1)*var(--tw-space-y-reverse));margin-block-end:calc(calc(var(--spacing)*1)*calc(1 - var(--tw-space-y-reverse)))}
:where(.space-y-1\.5>:not(:last-child)){--tw-space-y-reverse:0;margin-block-start:calc(calc(var(--spacing)*1.5)*var(--tw-space-y-reverse));margin-block-end:calc(calc(var(--spacing)*1.5)*calc(1 - var(--tw-space-y-reverse)))}
:where(.space-y-2>:not(:last-child)){--tw-space-y-reverse:0;margin-block-start:calc(calc(var(--spacing)*2)*var(--tw-space-y-reverse));margin-block-end:calc(calc(var(--spacing)*2)*calc(1 - var(--tw-space-y-reverse)))}
:where(.space-y-3>:not(:last-child)){--tw-space-y-reverse:0;margin-block-start:calc(calc(var(--spacing)*3)*var(--tw-space-y-reverse));margin-block-end:calc(calc(var(--spacing)*3)*calc(1 - var(--tw-space-y-reverse)))}
:where(.space-y-6>:not(:last-child)){--tw-space-y-reverse:0;margin-block-start:calc(calc(var(--spacing)*6)*var(--tw-space-y-reverse));margin-block-end:calc(calc(var(--spacing)*6)*calc(1 - var(--tw-space-y-reverse)))}
.gap-x-4{column-gap:calc(var(--spacing)*4)}
.gap-y-1\.5{row-gap:calc(var(--spacing)*1.5)}
:where(.divide-y>:not(:last-child)){--tw-divide-y-reverse:0;border-bottom-style:var(--tw-border-style);border-top-style:var(--tw-border-style);border-top-width:calc(1px*var(--tw-divide-y-reverse));border-bottom-width:calc(1px*calc(1 - var(--tw-divide-y-reverse)))}
:where(.divide-slate-100>:not(:last-child)){border-color:var(--color-slate-100)}
.self-center{align-self:center}
.truncate{text-overflow:ellipsis;white-space:nowrap;overflow:hidden}
.overflow-auto{overflow:auto}
.overflow-hidden{overflow:hidden}
.overflow-x-auto{overflow-x:auto}
.overflow-x-hidden{overflow-x:hidden}
.overflow-y-auto{overflow-y:auto}
.rounded{border-radius:.25rem}
.rounded-full{border-radius:9999px}
.rounded-lg{border-radius:var(--radius-lg)}
.rounded-md{border-radius:var(--radius-md)}
.rounded-sm{border-radius:var(--radius-sm)}
.rounded-xl{border-radius:var(--radius-xl)}
.rounded-b-lg{border-bottom-right-radius:var(--radius-lg);border-bottom-left-radius:var(--radius-lg)}
.border{border-style:var(--tw-border-style);border-width:1px}
.border-2{border-style:var(--tw-border-style);border-width:2px}
.border-t{border-top-style:var(--tw-border-style);border-top-width:1px}
.border-r{border-right-style:var(--tw-border-style);border-right-width:1px}
.border-b{border-bottom-style:var(--tw-border-style);border-bottom-width:1px}
.border-amber-500{border-color:var(--color-amber-500)}
.border-blue-200{border-color:var(--color-blue-200)}
.border-blue-600{border-color:var(--color-blue-600)}
.border-emerald-200{border-color:var(--color-emerald-200)}
.border-fuchsia-200{border-color:var(--color-fuchsia-200)}
.border-indigo-100{border-color:var(--color-indigo-100)}
.border-indigo-200{border-color:var(--color-indigo-200)}
.border-indigo-600{border-color:var(--color-indigo-600)}
.border-purple-200{border-color:var(--color-purple-200)}
.border-purple-300{border-color:var(--color-purple-300)}
.border-purple-600{border-color:var(--color-purple-600)}
.border-rose-200{border-color:var(--color-rose-200)}
.border-rose-300{border-color:var(--color-rose-300)}
.border-rose-500{border-color:var(--color-rose-500)}
.border-slate-50{border-color:var(--color-slate-50)}
.border-slate-100{border-color:var(--color-slate-100)}
.border-slate-200{border-color:var(--color-slate-200)}
.border-slate-300{border-color:var(--color-slate-300)}
.border-slate-700{border-color:var(--color-slate-700)}
.border-slate-800{border-color:var(--color-slate-800)}
.border-violet-200{border-color:var(--color-violet-200)}
.border-violet-600{border-color:var(--color-violet-600)}
.bg-amber-50{background-color:var(--color-amber-50)}
.bg-amber-100{background-color:var(--color-amber-100)}
.bg-amber-500{background-color:var(--color-amber-500)}
.bg-blue-50{background-color:var(--color-blue-50)}
.bg-blue-100{background-color:var(--color-blue-100)}
.bg-blue-400{background-color:var(--color-blue-400)}
.bg-blue-500{background-color:var(--color-blue-500)}
.bg-blue-600{background-color:var(--color-blue-600)}
.bg-emerald-50{background-color:var(--color-emerald-50)}
.bg-emerald-50\/30{background-color:#ecfdf54d}
@supports (color:currentColor){.bg-emerald-50\/30{background-color:var(--color-emerald-50)}}
.bg-emerald-100{background-color:var(--color-emerald-100)}
.bg-emerald-500{background-color:var(--color-emerald-500)}
.bg-emerald-600{background-color:var(--color-emerald-600)}
.bg-fuchsia-50\/60{background-color:#fdf4ff99}
@supports (color:currentColor){.bg-fuchsia-50\/60{background-color:var(--color-fuchsia-50)}}
.bg-fuchsia-600{background-color:var(--color-fuchsia-600)}
.bg-indigo-50{background-color:var(--color-indigo-50)}
.bg-indigo-500{background-color:var(--color-indigo-500)}
.bg-indigo-600{background-color:var(--color-indigo-600)}
.bg-purple-50{background-color:var(--color-purple-50)}
.bg-purple-100{background-color:var(--color-purple-100)}
.bg-purple-600{background-color:var(--color-purple-600)}
.bg-red-500{background-color:var(--color-red-500)}
.bg-rose-50{background-color:var(--color-rose-50)}
.bg-rose-50\/30{background-color:#fff1f24d}
@supports (color:currentColor){.bg-rose-50\/30{background-color:var(--color-rose-50)}}
.bg-rose-50\/50{background-color:#fff1f280}
@supports (color:currentColor){.bg-rose-50\/50{background-color:var(--color-rose-50)}}
.bg-rose-100{background-color:var(--color-rose-100)}
.bg-rose-500{background-color:var(--color-rose-500)}
.bg-sky-50{background-color:var(--color-sky-50)}
.bg-sky-100{background-color:var(--color-sky-100)}
.bg-slate-50{background-color:var(--color-slate-50)}
.bg-slate-100{background-color:var(--color-slate-100)}
.bg-slate-200{background-color:var(--color-slate-200)}
.bg-slate-400{background-color:var(--color-slate-400)}
.bg-slate-700{background-color:var(--color-slate-700)}
.bg-slate-800{background-color:var(--color-slate-800)}
.bg-slate-800\/80{background-color:#1d293dcc}
@supports (color:currentColor){.bg-slate-800\/80{background-color:var(--color-slate-800)}}
.bg-slate-900{background-color:var(--color-slate-900)}
.bg-slate-900\/60{background-color:#0f172b99}
@supports (color:currentColor){.bg-slate-900\/60{background-color:var(--color-slate-900)}}
.bg-transparent{background-color:#0000}
.bg-violet-50{background-color:var(--color-violet-50)}
.bg-violet-600{background-color:var(--color-violet-600)}
.bg-white{background-color:var(--color-white)}
.p-4{padding:calc(var(--spacing)*4)}
.p-5{padding:calc(var(--spacing)*5)}
.p-6{padding:calc(var(--spacing)*6)}
.px-0\.5{padding-inline:calc(var(--spacing)*.5)}
.px-1{padding-inline:calc(var(--spacing)*1)}
.px-1\.5{padding-inline:calc(var(--spacing)*1.5)}
.px-2{padding-inline:calc(var(--spacing)*2)}
.px-2\.5{padding-inline:calc(var(--spacing)*2.5)}
.px-3{padding-inline:calc(var(--spacing)*3)}
.px-4{padding-inline:calc(var(--spacing)*4)}
.px-5{padding-inline:calc(var(--spacing)*5)}
.px-6{padding-inline:calc(var(--spacing)*6)}
.py-0\.5{padding-block:calc(var(--spacing)*.5)}
.py-1{padding-block:calc(var(--spacing)*1)}
.py-1\.5{padding-block:calc(var(--spacing)*1.5)}
.py-2{padding-block:calc(var(--spacing)*2)}
.py-2\.5{padding-block:calc(var(--spacing)*2.5)}
.py-3{padding-block:calc(var(--spacing)*3)}
.py-4{padding-block:calc(var(--spacing)*4)}
.py-6{padding-block:calc(var(--spacing)*6)}
.py-12{padding-block:calc(var(--spacing)*12)}
.pt-1{padding-top:calc(var(--spacing)*1)}
.pt-2{padding-top:calc(var(--spacing)*2)}
.pr-6{padding-right:calc(var(--spacing)*6)}
.pl-6{padding-left:calc(var(--spacing)*6)}
.text-center{text-align:center}
.text-left{text-align:left}
.text-right{text-align:right}
.font-mono{font-family:var(--font-geist-mono)}
.text-lg{font-size:var(--text-lg);line-height:var(--tw-leading,var(--text-lg--line-height))}
.text-sm{font-size:var(--text-sm);line-height:var(--tw-leading,var(--text-sm--line-height))}
.text-xl{font-size:var(--text-xl);line-height:var(--tw-leading,var(--text-xl--line-height))}
.text-xs{font-size:var(--text-xs);line-height:var(--tw-leading,var(--text-xs--line-height))}
.text-\[8px\]{font-size:8px}
.text-\[9px\]{font-size:9px}
.text-\[10px\]{font-size:10px}
.text-\[11px\]{font-size:11px}
.text-\[12px\]{font-size:12px}
.leading-none{--tw-leading:1;line-height:1}
.leading-relaxed{--tw-leading:var(--leading-relaxed);line-height:var(--leading-relaxed)}
.font-bold{--tw-font-weight:var(--font-weight-bold);font-weight:var(--font-weight-bold)}
.font-medium{--tw-font-weight:var(--font-weight-medium);font-weight:var(--font-weight-medium)}
.font-normal{--tw-font-weight:var(--font-weight-normal);font-weight:var(--font-weight-normal)}
.font-semibold{--tw-font-weight:var(--font-weight-semibold);font-weight:var(--font-weight-semibold)}
.tracking-\[0\.15em\]{--tw-tracking:.15em;letter-spacing:.15em}
.tracking-wide{--tw-tracking:var(--tracking-wide);letter-spacing:var(--tracking-wide)}
.tracking-wider{--tw-tracking:var(--tracking-wider);letter-spacing:var(--tracking-wider)}
.break-words{overflow-wrap:break-word}
.break-all{word-break:break-all}
.whitespace-pre-wrap{white-space:pre-wrap}
.text-amber-600{color:var(--color-amber-600)}
.text-amber-700{color:var(--color-amber-700)}
.text-amber-800{color:var(--color-amber-800)}
.text-blue-500{color:var(--color-blue-500)}
.text-blue-600{color:var(--color-blue-600)}
.text-blue-700{color:var(--color-blue-700)}
.text-blue-800{color:var(--color-blue-800)}
.text-emerald-500{color:var(--color-emerald-500)}
.text-emerald-600{color:var(--color-emerald-600)}
.text-emerald-700{color:var(--color-emerald-700)}
.text-emerald-800{color:var(--color-emerald-800)}
.text-fuchsia-600{color:var(--color-fuchsia-600)}
.text-fuchsia-700{color:var(--color-fuchsia-700)}
.text-indigo-300{color:var(--color-indigo-300)}
.text-indigo-500{color:var(--color-indigo-500)}
.text-indigo-600{color:var(--color-indigo-600)}
.text-indigo-700{color:var(--color-indigo-700)}
.text-orange-600{color:var(--color-orange-600)}
.text-purple-500{color:var(--color-purple-500)}
.text-purple-600{color:var(--color-purple-600)}
.text-purple-700{color:var(--color-purple-700)}
.text-purple-800{color:var(--color-purple-800)}
.text-red-600{color:var(--color-red-600)}
.text-rose-500{color:var(--color-rose-500)}
.text-rose-600{color:var(--color-rose-600)}
.text-rose-700{color:var(--color-rose-700)}
.text-rose-800{color:var(--color-rose-800)}
.text-sky-600{color:var(--color-sky-600)}
.text-sky-700{color:var(--color-sky-700)}
.text-slate-200{color:var(--color-slate-200)}
.text-slate-300{color:var(--color-slate-300)}
.text-slate-400{color:var(--color-slate-400)}
.text-slate-500{color:var(--color-slate-500)}
.text-slate-600{color:var(--color-slate-600)}
.text-slate-700{color:var(--color-slate-700)}
.text-slate-800{color:var(--color-slate-800)}
.text-slate-900{color:var(--color-slate-900)}
.text-violet-600{color:var(--color-violet-600)}
.text-white{color:var(--color-white)}
.text-white\/70{color:#ffffffb3}
@supports (color:currentColor){.text-white\/70{color:var(--color-white)}}
.text-white\/80{color:#fffc}
@supports (color:currentColor){.text-white\/80{color:var(--color-white)}}
.uppercase{text-transform:uppercase}
.italic{font-style:italic}
.line-through{text-decoration-line:line-through}
.underline{text-decoration-line:underline}
.decoration-dotted{text-decoration-style:dotted}
.accent-indigo-600{accent-color:var(--color-indigo-600)}
.opacity-0{opacity:0}
.opacity-20{opacity:.2}
.opacity-40{opacity:.4}
.opacity-60{opacity:.6}
.opacity-70{opacity:.7}
.opacity-75{opacity:.75}
.opacity-100{opacity:1}
.shadow-2xl{--tw-shadow:0 25px 50px -12px var(--tw-shadow-color,#00000040);box-shadow:var(--tw-inset-shadow),var(--tw-inset-ring-shadow),var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow)}
.shadow-lg{--tw-shadow:0 10px 15px -3px var(--tw-shadow-color,#0000001a),0 4px 6px -4px var(--tw-shadow-color,#0000001a);box-shadow:var(--tw-inset-shadow),var(--tw-inset-ring-shadow),var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow)}
.shadow-sm{--tw-shadow:0 1px 3px 0 var(--tw-shadow-color,#0000001a),0 1px 2px -1px var(--tw-shadow-color,#0000001a);box-shadow:var(--tw-inset-shadow),var(--tw-inset-ring-shadow),var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow)}
.shadow-xl{--tw-shadow:0 20px 25px -5px var(--tw-shadow-color,#0000001a),0 8px 10px -6px var(--tw-shadow-color,#0000001a);box-shadow:var(--tw-inset-shadow),var(--tw-inset-ring-shadow),var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow)}
.ring-4{--tw-ring-shadow:var(--tw-ring-inset,)0 0 0 calc(4px + var(--tw-ring-offset-width))var(--tw-ring-color,currentcolor);box-shadow:var(--tw-inset-shadow),var(--tw-inset-ring-shadow),var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow)}
.ring-blue-400{--tw-ring-color:var(--color-blue-400)}
.ring-offset-2{--tw-ring-offset-width:2px;--tw-ring-offset-shadow:var(--tw-ring-inset,)0 0 0 var(--tw-ring-offset-width)var(--tw-ring-offset-color)}
.grayscale{--tw-grayscale:grayscale(100%);filter:var(--tw-blur,)var(--tw-brightness,)var(--tw-contrast,)var(--tw-grayscale,)var(--tw-hue-rotate,)var(--tw-invert,)var(--tw-saturate,)var(--tw-sepia,)var(--tw-drop-shadow,)}
.backdrop-blur-sm{--tw-backdrop-blur:blur(var(--blur-sm));-webkit-backdrop-filter:var(--tw-backdrop-blur,)var(--tw-backdrop-brightness,)var(--tw-backdrop-contrast,)var(--tw-backdrop-grayscale,)var(--tw-backdrop-hue-rotate,)var(--tw-backdrop-invert,)var(--tw-backdrop-opacity,)var(--tw-backdrop-saturate,)var(--tw-backdrop-sepia,);backdrop-filter:var(--tw-backdrop-blur,)var(--tw-backdrop-brightness,)var(--tw-backdrop-contrast,)var(--tw-backdrop-grayscale,)var(--tw-backdrop-hue-rotate,)var(--tw-backdrop-invert,)var(--tw-backdrop-opacity,)var(--tw-backdrop-saturate,)var(--tw-backdrop-sepia,)}
.transition-all{transition-property:all;transition-timing-function:var(--tw-ease,var(--default-transition-timing-function));transition-duration:var(--tw-duration,var(--default-transition-duration))}
.transition-colors{transition-property:color,background-color,border-color,outline-color,text-decoration-color,fill,stroke,--tw-gradient-from,--tw-gradient-via,--tw-gradient-to;transition-timing-function:var(--tw-ease,var(--default-transition-timing-function));transition-duration:var(--tw-duration,var(--default-transition-duration))}
.duration-300{--tw-duration:.3s;transition-duration:.3s}
.ease-in-out{--tw-ease:var(--ease-in-out);transition-timing-function:var(--ease-in-out)}
.select-none{-webkit-user-select:none;user-select:none}
.placeholder\:text-slate-400::placeholder{color:var(--color-slate-400)}
@media (hover:hover){.hover\:border-amber-300:hover{border-color:var(--color-amber-300)}
.hover\:border-blue-300:hover{border-color:var(--color-blue-300)}
.hover\:border-indigo-400:hover{border-color:var(--color-indigo-400)}
.hover\:border-rose-300:hover{border-color:var(--color-rose-300)}
.hover\:border-rose-400:hover{border-color:var(--color-rose-400)}
.hover\:border-slate-400:hover{border-color:var(--color-slate-400)}
.hover\:border-violet-300:hover{border-color:var(--color-violet-300)}
.hover\:bg-blue-50:hover{background-color:var(--color-blue-50)}
.hover\:bg-blue-400:hover{background-color:var(--color-blue-400)}
.hover\:bg-blue-500:hover{background-color:var(--color-blue-500)}
.hover\:bg-blue-700:hover{background-color:var(--color-blue-700)}
.hover\:bg-emerald-50:hover{background-color:var(--color-emerald-50)}
.hover\:bg-emerald-700:hover{background-color:var(--color-emerald-700)}
.hover\:bg-fuchsia-700:hover{background-color:var(--color-fuchsia-700)}
.hover\:bg-indigo-100:hover{background-color:var(--color-indigo-100)}
.hover\:bg-indigo-700:hover{background-color:var(--color-indigo-700)}
.hover\:bg-orange-50:hover{background-color:var(--color-orange-50)}
.hover\:bg-purple-50:hover{background-color:var(--color-purple-50)}
.hover\:bg-red-50:hover{background-color:var(--color-red-50)}
.hover\:bg-rose-50:hover{background-color:var(--color-rose-50)}
.hover\:bg-slate-50:hover{background-color:var(--color-slate-50)}
.hover\:bg-slate-200:hover{background-color:var(--color-slate-200)}
.hover\:bg-slate-700:hover{background-color:var(--color-slate-700)}
.hover\:bg-slate-800:hover{background-color:var(--color-slate-800)}
.hover\:bg-white\/20:hover{background-color:#fff3}
@supports (color:currentColor){.hover\:bg-white\/20:hover{background-color:var(--color-white)}}
.hover\:text-blue-500:hover{color:var(--color-blue-500)}
.hover\:text-blue-800:hover{color:var(--color-blue-800)}
.hover\:text-fuchsia-600:hover{color:var(--color-fuchsia-600)}
.hover\:text-red-500:hover{color:var(--color-red-500)}
.hover\:text-rose-600:hover{color:var(--color-rose-600)}
.hover\:text-rose-700:hover{color:var(--color-rose-700)}
.hover\:text-rose-800:hover{color:var(--color-rose-800)}
.hover\:text-slate-500:hover{color:var(--color-slate-500)}
.hover\:text-slate-600:hover{color:var(--color-slate-600)}
.hover\:text-slate-700:hover{color:var(--color-slate-700)}
.hover\:text-slate-800:hover{color:var(--color-slate-800)}
.hover\:text-white:hover{color:var(--color-white)}
.hover\:underline:hover{text-decoration-line:underline}}
.focus\:border-blue-400:focus{border-color:var(--color-blue-400)}
.focus\:border-fuchsia-500:focus{border-color:var(--color-fuchsia-500)}
.focus\:border-transparent:focus{border-color:#0000}
.focus\:ring-1:focus{--tw-ring-shadow:var(--tw-ring-inset,)0 0 0 calc(1px + var(--tw-ring-offset-width))var(--tw-ring-color,currentcolor);box-shadow:var(--tw-inset-shadow),var(--tw-inset-ring-shadow),var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow)}
.focus\:ring-2:focus{--tw-ring-shadow:var(--tw-ring-inset,)0 0 0 calc(2px + var(--tw-ring-offset-width))var(--tw-ring-color,currentcolor);box-shadow:var(--tw-inset-shadow),var(--tw-inset-ring-shadow),var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow)}
.focus\:ring-blue-400:focus{--tw-ring-color:var(--color-blue-400)}
.focus\:ring-blue-500:focus{--tw-ring-color:var(--color-blue-500)}
.focus\:ring-indigo-500:focus{--tw-ring-color:var(--color-indigo-500)}
.focus\:ring-slate-400:focus{--tw-ring-color:var(--color-slate-400)}
.focus\:outline-none:focus{--tw-outline-style:none;outline-style:none}
.active\:cursor-grabbing:active{cursor:grabbing}
.disabled\:cursor-not-allowed:disabled{cursor:not-allowed}
.disabled\:bg-slate-200:disabled{background-color:var(--color-slate-200)}
.disabled\:text-slate-500:disabled{color:var(--color-slate-500)}
.disabled\:opacity-50:disabled{opacity:.5}
@media (min-width:40rem){.sm\:grid-cols-3{grid-template-columns:repeat(3,minmax(0,1fr))}}
@media (min-width:48rem){.md\:grid-cols-2{grid-template-columns:repeat(2,minmax(0,1fr))}
.md\:grid-cols-4{grid-template-columns:repeat(4,minmax(0,1fr))}}
@media (min-width:64rem){.lg\:grid-cols-6{grid-template-columns:repeat(6,minmax(0,1fr))}}


/* === Default font stack + fallback vars (Salesforce-safe) === */
/* Override font families for environments where the Geist font isn't loaded
   (Salesforce Lightning, raw HTML). Use :where() for zero-specificity so the
   marketing site's own --font-* vars from globals.css still win when both
   stylesheets are present. */
:where(:root) {
  --font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  --font-mono: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace;
  --font-geist-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  --font-geist-mono: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace;
}


/* === Gantt library (.ng-*) overrides — copied from DeliveryTimelineV5.tsx === */

        /* Grid panel font matching v3 canvas renderer */
        .ng-grid {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
          font-size: 12px !important;
          color: #1f2937 !important;
          letter-spacing: -0.01em;
        }
        /* Ensure grid table has no border-spacing that could affect row alignment */
        .ng-grid table {
          border-collapse: collapse !important;
          border-spacing: 0 !important;
        }
        .ng-grid-header {
          background: #f3f4f6 !important;
          visibility: hidden !important;
        }
        .ng-grid-th {
          font-size: 12px !important;
          font-weight: 700 !important;
          color: #1f2937 !important;
          padding: 0 6px !important;
        }
        /* Parent/group rows: bold like v3 (but not priority-group header rows) */
        .ng-grid-row:not(.ng-group-row) .ng-tree-cell .ng-expand-icon + .ng-grid-cell-text {
          font-weight: 700 !important;
          color: #1f2937 !important;
        }
        /* Child rows (indented): lighter/muted like v3 canvas */
        .ng-grid-row .ng-tree-cell .ng-expand-spacer + .ng-grid-cell-text {
          font-weight: 400 !important;
          color: #6b7280 !important;
          font-size: 11px !important;
        }
        .ng-grid-cell {
          padding-top: 0 !important;
          padding-right: 6px !important;
          padding-bottom: 0 !important;
          padding-left: 6px; /* no !important — JS depth-indent overrides this */
          line-height: 32px !important;
        }
        /* Zero out the spacer so ≡ aligns with ▶ at the same depth */
        .ng-expand-spacer {
          width: 0 !important;
          min-width: 0 !important;
        }
        /* Expand arrow styling */
        .ng-expand-icon {
          font-size: 9px !important;
          opacity: 0.5 !important;
          color: #6b7280 !important;
          width: 14px !important;
          min-width: 14px !important;
        }
        .ng-expand-icon:hover {
          opacity: 1 !important;
        }
        /* Row borders — use box-shadow instead of border to avoid layout shift */
        .ng-grid-row {
          border: none !important;
          box-shadow: inset 0 -1px 0 #f3f4f6;
          box-sizing: border-box !important;
        }
        /* Leaf rows are draggable from anywhere */
        .ng-grid-row:not(.ng-group-row) {
          cursor: grab;
        }
        .ng-grid-row:not(.ng-group-row):hover {
          background: rgba(59,130,246,0.04) !important;
          outline: 1px solid rgba(59,130,246,0.12) !important;
          outline-offset: -1px;
        }
        .ng-grid-row:not(.ng-group-row):active {
          cursor: grabbing;
        }
        .ng-grid-row td {
          border: none !important;
          box-sizing: border-box !important;
        }
        /* Remove cell right borders for cleaner look */
        .ng-grid-cell {
          border-right: none !important;
        }
        .ng-grid-th {
          border-right: none !important;
        }
        /* Kill alternating row color — depth shading handles backgrounds.
           Use unset (not !important) so inline depth-shading can override. */
        .ng-row-alt:not(.ng-group-row) {
          background: unset;
        }
        /* Keep the gantt canvas sticky so it stays in view on horizontal scroll.
           The nimbus-gantt library sets this at init (core.js:1332) but something
           can reset it; this !important ensures it's always honoured. */
        .ng-scroll-content > canvas {
          position: sticky !important;
          left: 0 !important;
        }
        /* Belt-and-suspenders: hide any legacy stripe overlay div from cached
           old code that created a position:absolute div bleeding past canvas. */
        [data-depth-stripes] {
          display: none !important;
        }
        /* Bucket header rows (NOW / NEXT / PLANNED / etc.)
           Strong background from GROUP_BG, white text, no top-accent border. */
        .ng-group-row {
          font-weight: 700;
          font-size: 11px;
          letter-spacing: 0.03em;
          box-sizing: border-box !important;
          box-shadow: none !important;
          color: #fff !important;
        }
        .ng-group-row .ng-grid-cell-text {
          font-weight: 700 !important;
          font-size: 12px !important;
          color: #fff !important;
          letter-spacing: 0.02em;
          color: inherit !important;
          text-transform: uppercase;
        }
        .ng-group-row .ng-expand-icon {
          color: inherit !important;
          opacity: 0.5 !important;
        }
        /* Hours/count column for group rows — full size, never truncate */
        .ng-group-row .ng-grid-cell[data-field="hoursLabel"] {
          font-weight: 600 !important;
          font-size: 11px !important;
          color: inherit !important;
          opacity: 0.75;
          white-space: nowrap !important;
          overflow: visible !important;
          text-overflow: unset !important;
        }
        /* Hours column for child rows — monospace, muted, lighter weight */
        .ng-grid-cell[data-field="hoursLabel"] {
          font-family: 'SF Mono', 'Cascadia Code', 'Consolas', monospace;
          font-size: 10px;
          color: #94a3b8;
          font-weight: 400;
        }
        /* Drag handle icon — always visible, like v3 sidebar */
        .ng-drag-handle {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          cursor: grab;
          opacity: 0.3;
          font-size: 11px;
          color: #94a3b8;
          vertical-align: middle;
          user-select: none;
          width: 14px;
          height: 14px;
          flex-shrink: 0;
          margin-left: -5px !important;
          margin-right: 4px;
        }
        .ng-grid-row:hover .ng-drag-handle {
          opacity: 0.6;
          color: #64748b;
        }
        .ng-drag-handle:active {
          cursor: grabbing;
          opacity: 1;
        }
        /* Selected row — subtle highlight that doesn't clash with group bg colors */
        .ng-row-selected:not(.ng-group-row) {
          background: rgba(59, 130, 246, 0.06) !important;
          box-shadow: inset 3px 0 0 #3b82f6 !important;
        }
        .ng-row-selected.ng-group-row {
          box-shadow: inset 0 2px 0 currentColor, inset 3px 0 0 currentColor, inset 0 -1px 0 #f3f4f6 !important;
        }
        /* Canvas cursor: let core.js hit-test control cursor via inline style */
        /* Group row hours column inherits group color too */
        .ng-group-row .ng-grid-cell[data-field="hoursLabel"] {
          color: inherit !important;
          opacity: 0.7;
        }

        /*
         * DEPTH-INDENTATION FIX — CSS !important beats the library's inline
         * padding-left (which has no !important).  We read the library's own
         * depth-indicator value (28 / 48 / 68 / 88 px) and map it to our compact
         * spacing so that:
         *   • Depth-0 parent ▼ caret aligns with the NOW/NEXT bucket ▼ caret (both at 8px)
         *   • Depth-1+ leaf ≡ hamburgers align with their sibling parent ▼ carets
         *
         * Formula: parent_padding(d) = 8 + d×10
         *          leaf_padding(d)   = max(0, 8 + d×10 − 10) = max(0, (d−1)×10 + 8 − 10)
         *   d=0 → parent: 8px ; leaf:  0px (hamburger at 10px)
         *   d=1 → parent: 18px; leaf:  8px (hamburger at 18px = parent caret ✓)
         *   d=2 → parent: 28px; leaf: 18px (hamburger at 28px = parent caret ✓)
         *   d=3 → parent: 38px; leaf: 28px (hamburger at 38px = parent caret ✓)
         *
         * Library depth→px map: depth 0→28px, 1→48px, 2→68px, 3→88px.
         * Selectors use :has() (Chrome 105+) to distinguish parent vs leaf rows.
         */

        /* ── depth 0 (library sets 28px) ─────────────────────────────── */
        /* Both parent (▶) and leaf (≡) align at same X — icon type is the distinction */
        .ng-grid-row:not(.ng-group-row)
          .ng-tree-cell[style*="padding-left: 28px"] { padding-left: 8px  !important; }

        /* ── depth 1 (library sets 48px) ─────────────────────────────── */
        .ng-grid-row:not(.ng-group-row)
          .ng-tree-cell[style*="padding-left: 48px"] { padding-left: 18px !important; }

        /* ── depth 2 (library sets 68px) ─────────────────────────────── */
        .ng-grid-row:not(.ng-group-row)
          .ng-tree-cell[style*="padding-left: 68px"] { padding-left: 28px !important; }

        /* ── depth 3 (library sets 88px) — future-proofing ───────────── */
        /* ── depth 3 (library sets 88px) — future-proofing ──────────── */
        .ng-grid-row:not(.ng-group-row)
          .ng-tree-cell[style*="padding-left: 88px"] { padding-left: 38px !important; }
        /*
         * DEPTH-INDENT FALLBACK via CSS animation trick.
         * The JS chunk may be cached — this animation fires onAnimationStart which
         * the shading useEffect intercepts to re-apply correct indentation.
         * Animation name is deliberately unique so it only targets our container.
         */
        @keyframes mf-depth-check { from { outline-color: transparent; } to { outline-color: transparent; } }
        .ng-gantt-container {
          animation: mf-depth-check 0.001s linear 1 !important;
        }
      

/* force-rebuild-0.180 — break SF package static-resource dedup (cloudnimbustemplatecss missed PR #635/#636 hash update) */
