/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General 
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General  License for more details.
 *
 * You should have received a copy of the GNU Lesser General 
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

part of pdf;

class PdfOutput {
  /// This is the actual [PdfStream] used to write to.
  final PdfStream os;

  /// This vector contains offsets of each object
  List<PdfXref> offsets = [];

  /// This is used to track the /Root object (catalog)
  PdfObject rootID;

  /// This is used to track the /Info object (info)
  PdfObject infoID;

  /// This creates a Pdf [PdfStream]
  ///
  /// @param os The output stream to write the Pdf file to.
  PdfOutput(this.os) {
    os.putString("%PDF-1.4\n");
    os.putBytes([0x25, 0xC2, 0xA5, 0xC2, 0xB1, 0xC3, 0xAB, 0x0A]);
  }

  /// This method writes a [PdfObject] to the stream.
  ///
  /// @param ob [PdfObject] Obeject to write
  void write(PdfObject ob) {
    // Check the object to see if it's one that is needed in the trailer
    // object
    if (ob is PdfCatalog) rootID = ob;
    if (ob is PdfInfo) infoID = ob;

    offsets.add(PdfXref(ob.objser, os.offset));
    ob._write(os);
  }

  /// This closes the Stream, writing the xref table
  void close() {
    // we use baos to speed things up a little.
    // Also, offset is preserved, and marks the begining of this block.
    // This is required by Pdf at the end of the Pdf file.

    int xref = os.offset;

    os.putString("xref\n");

    // Now a single subsection for object 0
    //os.write("0 1\n0000000000 65535 f \n");

    // Now scan through the offsets list. The should be in sequence,
    // but just in case:
    int firstid = 0; // First id in block
    int lastid = -1; // The last id used
    var block = []; // xrefs in this block

    // We need block 0 to exist
    block.add(PdfXref(0, 0, generation: 65535));

    for (PdfXref x in offsets) {
      if (firstid == -1) firstid = x.id;

      // check to see if block is in range (-1 means empty)
      if (lastid > -1 && x.id != (lastid + 1)) {
        // no, so write this block, and reset
        writeblock(firstid, block);
        block = [];
        firstid = -1;
      }

      // now add to block
      block.add(x);
      lastid = x.id;
    }

    // now write the last block
    if (firstid > -1) writeblock(firstid, block);

    // now the trailer object
    os.putString("trailer\n<<\n");

    // the number of entries (REQUIRED)
    os.putString("/Size ");
    os.putString((offsets.length + 1).toString());
    os.putString("\n");

    // the /Root catalog indirect reference (REQUIRED)
    if (rootID != null) {
      os.putString("/Root ");
      os.putStream(rootID.ref());
      os.putString("\n");
    } else
      throw Exception("Root object is not present in document");

    // the /Info reference (OPTIONAL)
    if (infoID != null) {
      os.putString("/Info ");
      os.putStream(infoID.ref());
      os.putString("\n");
    }

    // end the trailer object
    os.putString(">>\nstartxref\n$xref\n%%EOF\n");
  }

  /// Writes a block of references to the Pdf file
  /// @param firstid ID of the first reference in this block
  /// @param block Vector containing the references in this block
  void writeblock(int firstid, var block) {
    os.putString("$firstid ${block.length}\n");
    //os.write("\n0000000000 65535 f\n");

    for (PdfXref x in block) {
      os.putString(x.ref());
      os.putString("\n");
    }
  }
}
