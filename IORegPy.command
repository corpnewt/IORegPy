#!/usr/bin/python
import os, sys, tempfile, shutil, plistlib, binascii, itertools, base64
from Scripts import *
if sys.version_info >= (3, 0):
    from itertools import zip_longest as zl
else:
    from itertools import izip_longest as zl

class IOReg:
    def __init__(self):
        self.u = utils.Utils("IORegPy")
        self.r = run.Run()
        self.scripts = "Scripts"
        self.ioreg = self._get_ioreg()
        self.path = []
        self.search_term = None

    def _get_ioreg(self):
        # Returns the plist data for 'ioreg -alp IODeviceTree'
        try:
            d = self.r.run({"args":["ioreg","-alp","IODeviceTree"]})[0]
            p = plist.loads(d)
        except:
            return {}
        return p

    def t(self, entry):
        # Returns the type of an entry
        if isinstance(entry, bool):
            return "Boolean"
        elif isinstance(entry, str):
            return "String"
        elif isinstance(entry, (dict, plistlib._InternalDict)):
            return "Dictionary"
        elif isinstance(entry, list):
            return "List"
        elif isinstance(entry, (int, float)):
            return "Number"
        elif isinstance(entry, (bytes, plistlib.Data)):
            return "Data"
        ty = str(type(entry))
        try:
            ty = ty.split("'")[1]
        except:
            pass
        return ty

    def format_hex(self, hex_data):
        hex_list = map(''.join, zl(*[iter(binascii.hexlify(hex_data))]*8, fillvalue=''))
        listlist = []
        temp = []
        for x in hex_list:
            if len(temp) < 7:
                temp.append(x)
                continue
            listlist.append(temp)
            temp = []
        # Make sure we get the last bit if needed
        if len(temp):
            listlist.append(temp)
        hex_blocks = []
        for x in listlist:
            hex_blocks.append(" ".join(x))
        if len(hex_blocks) > 1:
            return "Hex:    <{}\n         {}>".format(hex_blocks[0], "\n         ".join(hex_blocks[1:]))
        else:
            return "Hex:    <{}>".format(hex_blocks[0])
    
    def format_text(self, str_chars, **kwargs):
        str_chars = str(str_chars)
        if sys.version_info >= (3, 0):
            try:
                str_chars = str_chars.decode("utf-8")
            except:
                pass
        pad        = kwargs.get("pad", 9)
        block_size = kwargs.get("block_size", 62)
        block_pad  = kwargs.get("block_pad", "")
        max_blocks = kwargs.get("max_blocks", 1)
        blocks = map("".join, zl(*[iter(str_chars)]*block_size, fillvalue=""))
        l = []
        t = []
        for x in blocks:
            if len(t) < max_blocks:
                t.append(x)
                continue
            l.append(t)
            t = []
        if len(t):
            l.append(t)
        out_blocks = []
        for x in l:
            out_blocks.append(" "*pad + block_pad.join(x))
        return "\n".join(out_blocks)

    def main(self):
        # Gather our current path
        self.u.resize(80,24)
        pad = 12
        height = 24
        current = self.ioreg
        for x in self.path:
            current = current[x]
        count = 0
        d = None
        self.u.head()
        print("")
        print("Path: Root{}{}".format("/" if len(self.path) else "", "/".join([str(x) for x in self.path])))
        if self.search_term:
            pad += 1
            print("Searching for: {}".format(self.search_term))
        print("")
        if isinstance(current, (dict, plistlib._InternalDict)):
            # Is a dictionary - traverse the keys
            d = True
            search_keys = []
            found_text = ""
            for key in sorted(current):
                if self.search_term:
                    if not self.search_term.lower() in key.lower():
                        continue
                search_keys.append(key)
                count += 1
                found_text += "{}. {} ({})\n".format(count, key, self.t(current[key]))
            if len(found_text):
                print(found_text[:-1])
            else:
                print("No Keys Found")
            height = 24 if len(search_keys)+pad < 24 else len(search_keys)+pad
        elif isinstance(current, list):
            # Is a list - pick a number
            d = False
            print("Target is a list with {} item{}.".format(len(current), "" if len(current) == 1 else "s"))
            print("You can choose an item from 1-{}.".format(len(current)))
        else:
            # Not a list or dict - must be a value
            if isinstance(current, (plistlib.Data, bytes)):
                printed = False
                if isinstance(current, plistlib.Data):
                    current = current.data
                #try:
                print("Hex:\n{}".format(self.format_text(binascii.hexlify(current), block_size = 8, block_pad = " ", max_blocks = 7)))
                #    printed = True
                #except:
                #    pass
                #try:
                print("Base64:\n{}".format(self.format_text(base64.b64encode(current))))
                #    printed = True
                #except:
                #    pass
                try:
                    print("String:\n         {}".format(current))
                    printed = True
                except:
                    pass
                try:
                    print("Decimal:\n{}".format(self.format_text(str(int(binascii.hexlify(current), 16)))))
                    printed = True
                except:
                    pass
                if not printed:
                    print("Data would not convert to hex, base64, or string.")
            else:
                print(current)
        self.u.resize(80, 24 if height < 24 else height)
        print("Q. Quit")
        print("R. Go To Root")
        print("U. {}".format("Up A Level" if not self.search_term else "Clear Search"))
        print("")
        menu = self.u.grab("Please select an option:  ")
        if not len(menu):
            return
        if menu.lower() == "q":
            self.u.custom_quit()
        elif menu.lower() == "r":
            self.search_term = None
            self.path = []
            return
        elif menu.lower() == "u":
            if self.search_term:
                self.search_term = None
                return
            if len(self.path):
                del self.path[-1]
            return
        elif d == True:
            # Verify our menu is a valid list item
            try:
                menu = int(menu)
                self.path.append(search_keys[menu-1])
                self.search_term = None
            except:
                # Maybe it's a search term?
                self.search_term = menu
            return
        elif d == False:
            # Verify our menu is a valid index
            try:
                menu = int(menu)
                if menu > 0 and menu <= len(current):
                    # Valid range
                    self.path.append(menu-1)
            except:
                pass
            return

i = IOReg()
while True:
    i.main()
