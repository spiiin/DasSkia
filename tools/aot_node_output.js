Module.preRun = Module.preRun || [];
Module.preRun.push(function () {
    if (!process.env.DASSKIA_AOT_OUTPUT_DIR) throw new Error('DASSKIA_AOT_OUTPUT_DIR required');
    FS.mkdir('/aot-output');
    FS.mount(NODEFS, {root: process.env.DASSKIA_AOT_OUTPUT_DIR}, '/aot-output');
});
