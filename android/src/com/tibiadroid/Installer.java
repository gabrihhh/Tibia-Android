package com.tibiadroid;

import android.system.Os;
import android.system.OsConstants;

import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.io.RandomAccessFile;
import java.nio.charset.StandardCharsets;
import java.util.zip.GZIPInputStream;

/** Extrai o runtime (assets/runtime.tar.gz) e ajusta os caminhos fixos dos binários. */
final class Installer {
    interface Progress {
        void onProgress(String message);
    }

    private Installer() {}

    /** Extrai um .tar.gz (formatos ustar/PAX) em dest, preservando symlinks e permissões. */
    static void extractTarGz(InputStream raw, File dest, Progress progress) throws IOException {
        InputStream in = new GZIPInputStream(new BufferedInputStream(raw, 1 << 16), 1 << 16);
        byte[] header = new byte[512];
        String paxPath = null, paxLink = null;
        long count = 0;
        while (readFully(in, header)) {
            if (isZero(header)) break;
            String name = field(header, 0, 100);
            String prefix = field(header, 345, 155);
            if (!prefix.isEmpty()) name = prefix + "/" + name;
            int mode = (int) octal(header, 100, 8);
            long size = octal(header, 124, 12);
            char type = (char) header[156];
            String link = field(header, 157, 100);

            if (type == 'x' || type == 'g') {  // cabeçalho PAX: "len chave=valor\n"
                String pax = new String(readBytes(in, size), StandardCharsets.UTF_8);
                skipPadding(in, size);
                if (type == 'x') {
                    for (String line : pax.split("\n")) {
                        int sp = line.indexOf(' ');
                        if (sp < 0) continue;
                        String kv = line.substring(sp + 1);
                        if (kv.startsWith("path=")) paxPath = kv.substring(5);
                        else if (kv.startsWith("linkpath=")) paxLink = kv.substring(9);
                    }
                }
                continue;
            }
            if (paxPath != null) name = paxPath;
            if (paxLink != null) link = paxLink;
            paxPath = paxLink = null;

            File out = new File(dest, name);
            File parent = out.getParentFile();
            if (parent != null) parent.mkdirs();
            switch (type) {
                case '5':
                    out.mkdirs();
                    break;
                case '2':
                    out.delete();
                    try {
                        Os.symlink(link, out.getPath());
                    } catch (Exception e) {
                        throw new IOException("symlink " + name + " -> " + link, e);
                    }
                    break;
                default:  // '0' e '\0': arquivo comum
                    try (OutputStream os = new FileOutputStream(out)) {
                        copy(in, os, size);
                    }
                    skipPadding(in, size);
                    if ((mode & 0111) != 0) out.setExecutable(true, false);
                    break;
            }
            if (++count % 200 == 0) progress.onProgress("Preparando o ambiente… " + count + " arquivos");
        }
        in.close();
    }

    /**
     * O virgl_test_server_android (pacote do Termux) procura o ANGLE em caminhos fixos
     * do Termux. Troca pelos nossos, completando com bytes nulos (precisam caber).
     */
    static void patchVirgl(File virglServer, File virglDir) throws IOException {
        byte[] data;
        try (RandomAccessFile f = new RandomAccessFile(virglServer, "r")) {
            data = new byte[(int) f.length()];
            f.readFully(data);
        }
        String from = "/data/data/com.termux/files/usr/opt/angle-android/";
        String to = virglDir.getPath() + "/angle/";
        for (String sub : new String[] {"vulkan-null", "vulkan", "gl"}) {
            byte[] a = (from + sub + "\0").getBytes(StandardCharsets.UTF_8);
            byte[] b = (to + sub).getBytes(StandardCharsets.UTF_8);
            if (b.length >= a.length) throw new IOException("caminho do app longo demais para o virgl: " + to);
            int at = indexOf(data, a);
            if (at < 0) throw new IOException("string do ANGLE não encontrada no virgl: " + sub);
            System.arraycopy(b, 0, data, at, b.length);
            for (int i = b.length; i < a.length; i++) data[at + i] = 0;
        }
        try (FileOutputStream os = new FileOutputStream(virglServer)) {
            os.write(data);
        }
        virglServer.setExecutable(true, false);
    }

    static void deleteRecursive(File f) {
        if (f.isDirectory() && !isSymlink(f)) {
            File[] children = f.listFiles();
            if (children != null) for (File c : children) deleteRecursive(c);
        }
        f.delete();
    }

    private static boolean isSymlink(File f) {
        try {
            return OsConstants.S_ISLNK(Os.lstat(f.getPath()).st_mode);
        } catch (Exception e) {
            return false;
        }
    }

    private static int indexOf(byte[] data, byte[] needle) {
        outer:
        for (int i = 0; i <= data.length - needle.length; i++) {
            for (int j = 0; j < needle.length; j++) if (data[i + j] != needle[j]) continue outer;
            return i;
        }
        return -1;
    }

    private static boolean readFully(InputStream in, byte[] buf) throws IOException {
        int off = 0;
        while (off < buf.length) {
            int n = in.read(buf, off, buf.length - off);
            if (n < 0) return false;
            off += n;
        }
        return true;
    }

    private static byte[] readBytes(InputStream in, long size) throws IOException {
        ByteArrayOutputStream bos = new ByteArrayOutputStream((int) size);
        copy(in, bos, size);
        return bos.toByteArray();
    }

    private static void copy(InputStream in, OutputStream out, long size) throws IOException {
        byte[] buf = new byte[1 << 16];
        while (size > 0) {
            int n = in.read(buf, 0, (int) Math.min(buf.length, size));
            if (n < 0) throw new IOException("tar truncado");
            out.write(buf, 0, n);
            size -= n;
        }
    }

    private static void skipPadding(InputStream in, long size) throws IOException {
        long pad = (512 - (size % 512)) % 512;
        while (pad > 0) {
            long n = in.skip(pad);
            if (n <= 0) {
                if (in.read() < 0) throw new IOException("tar truncado");
                n = 1;
            }
            pad -= n;
        }
    }

    private static boolean isZero(byte[] b) {
        for (byte x : b) if (x != 0) return false;
        return true;
    }

    private static String field(byte[] h, int off, int len) {
        int end = off;
        while (end < off + len && h[end] != 0) end++;
        return new String(h, off, end - off, StandardCharsets.UTF_8);
    }

    private static long octal(byte[] h, int off, int len) {
        long v = 0;
        for (int i = off; i < off + len; i++) {
            byte c = h[i];
            if (c == 0 || c == ' ') {
                if (v != 0) break;
                continue;
            }
            v = v * 8 + (c - '0');
        }
        return v;
    }
}
