package com.bnprs.jni;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.charset.StandardCharsets;

public class qiScript {
    static {
        System.loadLibrary("Bpr.QiScript");
    }

    // JNI native method — UNCHANGED from the 2.22.28 release
    public native int qiCardTransmit(byte[] embData, char[] cardNum, int cnSize, int offset, char[] crName, int crSize, int chipProtocal);

    public static void main(String[] args) {
        qiScript qi = new qiScript();

        // Only main() differs from the released sample: reader name, data file, card number
        // and offset are now arguments so this can be re-run without a compiler.
        // Defaults are exactly the released values.
        String reader   = args.length > 0 ? args[0] : "OMNIKEY AG 3121 USB 00 00";
        String filePath = args.length > 1 ? args[1] : "qiscript.c.perso-bio.dat";
        String cardNumS = args.length > 2 ? args[2] : "1234567812345678";
        int    offset   = args.length > 3 ? Integer.parseInt(args[3]) : 1648;
        int    protocol = args.length > 4 ? Integer.parseInt(args[4]) : 0;

        System.out.println("jvm bits : " + System.getProperty("sun.arch.data.model"));
        System.out.println("reader   : [" + reader + "]");
        System.out.println("data file: " + filePath);
        System.out.println("offset   : " + offset + "   protocol: " + protocol);

        try {
            byte[] embData = Files.readAllBytes(Paths.get(filePath));
            System.out.println("data read: " + embData.length + " bytes");

            char[] cardNum = cardNumS.toCharArray();
            char[] crName  = reader.toCharArray();

            int result = qi.qiCardTransmit(embData, cardNum, cardNum.length, offset, crName, crName.length, protocol);
            System.out.println("result: " + result);

        } catch (IOException e) {
            System.err.println("Failed to open file: " + filePath);
            e.printStackTrace();
        }
    }
}
