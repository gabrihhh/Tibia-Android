package com.tibiadroid;

import android.content.Context;

import java.io.File;

final class Paths {
    private Paths() {}

    /** Raiz do runtime. Curta de propósito: o caminho é gravado dentro do binário do virgl. */
    static File home(Context c) {
        return new File(c.getFilesDir(), "rt");
    }
}
