# add output to every datalog relation!

from optparse import OptionParser
import os
import re

def get_rule_name(rule_decl):
    rule_name = re.findall(r"\.decl(.+)\(", rule_decl)[0]
    return rule_name

def add_output(filename):
    with open(filename, "r+") as f:
        lines = list(f)
        newlines = []
        need_insert_name = None
        for line in lines:
            if line.startswith(".decl"):
                if line.find("inline") == -1:
                    need_insert_name = get_rule_name(line)
                newlines.append(line)
                continue
            if need_insert_name is not None:
                # check if current position is still in decl body
                if (line.find(":") != -1) and (line.find(":-") == -1):
                    pass
                # already there
                elif line.startswith(".output") or line.startswith(".input"):
                    need_insert_name = None
                else:
                    newlines.append(".output"+need_insert_name+"\n")
                need_insert_name = None
                # newlines.append(".output"+get_rule_name(line)+"\n")
            newlines.append(line)
        f.seek(0)
        f.write("".join(newlines))

def add_output_dir(filedir):
    entries = os.listdir(filedir)
    for entry in entries:
        if entry.endswith(".dl"):
            add_output(filedir+"/"+entry)

if __name__ == "__main__":
    parser = OptionParser()
    parser.add_option("-F", "--file", dest="filename",
                      help="add .output to EVERY relation in a datalog file")
    parser.add_option("-D", "--dir", dest="dirname", help="add .output to EVERY relation in a datalog file dir")
    (options, args) = parser.parse_args()
    if options.dirname is not None:
        add_output_dir(options.dirname)
    elif options.filename is not None:
        add_output(options.filename)
