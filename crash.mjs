import { lstat, open } from 'node:fs/promises';

const p = '/etc/os-release';
const o = await open("/dev/stdout", "w");
const w = (msg) => o.write(msg);
const outer = 20;
const inner = 100000;


for (let i = 0; i < outer; i++) {
        const promises = [];
        for (let j = 0; j < inner; j++) {
                promises.push(lstat(p));
        }
        await Promise.all(promises);
        await w(".");
}

await w("\nDone");
