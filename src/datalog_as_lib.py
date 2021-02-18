# add output to every datalog relation!
# assume every file is valid datalog file

from optparse import OptionParser
import os
import re


class Relation:
    '''
    a datalog relation
    '''
    def __init__(self, name, arity, full_text, comp, is_out, is_input):
        self.name = name
        self.arity = arity
        self.full_text = full_text
        self.is_out = is_out
        self.is_input = is_input
        self.comp = comp

class DatalogTuple:
    '''
    a tuple in inside datalog DB
    '''
    def __init__(self, rule_name, arity, values):
        self.rule_name = rule_name
        self.arity = arity
        self.values = values

def get_rule_name(rule_decl):
    rule_name = re.findall(r"\.decl(.+)\(", rule_decl)[0]
    return rule_name.strip()

def get_comp_name(comp_decl):
    name = re.findall(r"\.comp(.+) *\{", comp_decl)[0]
    return name.strip()

def parse_rule_decl(rule_decl, comp='', is_out=False, is_input=False):
    '''
    parse a decl into a relation object
    if in a comp plz specify
    '''
    name = get_rule_name(rule_decl)
    # stuipid but works --- count :
    arity = rule_decl.count(':')
    return Relation(name, arity, rule_decl, comp, is_out, is_input)

def parse_init(init_line):
    left = re.findall(r'\.init +([a-zA-Z_]+) *=', init_line)[0]
    right = re.findall(r'= *([a-zA-Z_]+)', init_line)[0]
    return left, right

class DatalogLib:
    '''
    create a datalog lib from a folder
    '''
    def __init__(self, name, include_path='', override=True): 
        self.name = name
        self.include_path = include_path
        self.override = override
        self.rule_decls = []
        self.relations = []
        self.file_data = {}
        self.type_decls = []
        # map from comp name to list of rule decl
        self.comp_decls = {}
        self.inits = []
        self.init_map = {}
        self.inlines = []
        self.file_paths = []
    
    def add_dir(self, filedir, recurisve=False):
        entries = os.listdir(filedir)
        for entry in entries:
            if entry.endswith(".dl"):
                self.add_file(filedir+"/"+entry)
            elif os.path.isdir(filedir+"/"+entry):
                if recurisve:
                    self.add_dir(filedir+"/"+entry)

    def add_file(self, file_path):
        with open(file_path, "r+") as f:
            lines = list(f)
            full_text = "".join(lines)
            newlines = []
            need_insert_name = None
            current_rule = ""
            comp_name = ""
            comp_rules = []
            for line in lines:
                # check if a rule is complete
                if need_insert_name is not None:
                    # check if current position is still in decl body
                    if (line.find(":") != -1) and (line.find(":-") == -1) and (line.find(".decl") == -1):
                        current_rule = current_rule + line
                    # already there
                    # full_text.find('.output {}'.format(need_insert_name))
                    # elif re.findall(r'\.output +'+need_insert_name, full_text) != -1:
                    #     self.rule_decls.append(current_rule)
                    #     self.relations.append(parse_rule_decl(current_rule, comp_name, True))
                    #     need_insert_name = None
                    else:
                        is_out = False
                        if re.findall(r'\.output +'+need_insert_name+' *\n', full_text) != []:
                            print('.output '+need_insert_name)
                            is_out = True
                        else:
                            newlines.append(".output "+need_insert_name+"\n")
                        # check if we are now inside a comp
                        if comp_name == "":
                            self.relations.append(parse_rule_decl(current_rule, comp_name, is_out))
                            self.rule_decls.append(current_rule)
                        else:
                            self.relations.append(parse_rule_decl(current_rule, comp_name, is_out))
                            comp_rules.append(current_rule)
                        need_insert_name = None
                        current_rule = None
                    # newlines.append(".output"+get_rule_name(line)+"\n")
                if line.strip().startswith('.output'):
                    name = re.findall(r'\.output +([a-zA-Z_]+)', line)[0]
                    for r in self.relations:
                        if r.name == name:
                            r.is_out = True
                if line.strip().startswith('.input'):
                    name = re.findall(r'\.input +([a-zA-Z_]+)', line)[0]
                    for r in self.relations:
                        if r.name == name:
                            r.is_input = True
                if line.strip().startswith(".type"):
                    self.type_decls.append(line)
                if line.strip().startswith(".init"):
                    l, r = parse_init(line.strip())
                    self.init_map[l] = r
                    self.inits.append(line)
                # find comp
                if line.strip().startswith(".comp"):
                    comp_name = get_comp_name(line)
                if line.strip().endswith("}"):
                    self.comp_decls[comp_name] = comp_rules
                    comp_rules = []
                    comp_name = ""
                # find decl
                if line.strip().startswith(".decl"):
                    # handle inlines else where
                    if line.find("inline") == -1:
                        need_insert_name = get_rule_name(line)
                        current_rule = line
                newlines.append(line)
            self.file_data[file_path] = "".join(newlines)
        # self.file_paths.append(file_path)
            # # find all inlines def
            # inline_decls = re.findall(r"\.decl .+ inline", self.file_data[filename])
            # for i_decl in inline_decls:
            #     i_name = get_rule_name(i_decl)

    def outside_rule_names(self):
        '''
        return all rule name used but not declared in this file
        '''
        out_rule_names = []
        for fpath in self.file_data.keys():
            with open(fpath, 'r') as f:
                fdata = f.read()
                all_rule_names = re.findall(r'([a-zA-Z_]+)\(.+\)', fdata)
                for n in all_rule_names:
                    r, _ = self.find_decl_by_name(n)
                    if r is None:
                        out_rule_names.append(n)
        out_rule_names = list(set(out_rule_names))
        # print(out_rule_names)
        return out_rule_names

    def is_rule_exists(self, name):
        r, _ = self.find_decl_by_name(name)
        if r is not None:
            return True
        else:
            return False

    def find_decl_by_name(self, name):
        '''
        return the declaration of a rule, and it's comp, if it doesn't belong to any
        comp return None
        '''
        for cname, crules in self.comp_decls.items():
            for r in crules:
                if get_rule_name(r) == name:
                    return r, cname
        for d in self.rule_decls:
            if get_rule_name(d) == name:
                return d, None
        return None, None    

    def rewrite_rule(self):
        if self.override:
            for fname,data in self.file_data.items():
                with open(fname, "w+") as f:
                    f.seek(0)
                    f.write(data)
        # customize output dir not implement
    
    def generate_inlcude(self, all_out=False, select_outs=[], to_disk=True):
        buf = ''
        if select_outs == []:
            select_outs = list(map(lambda r: r.name, self.relations))
        # print(select_outs)
        # if all_out:
        #     for decl in self.type_decls:
        #         buf = buf + decl
        #     for i in self.inits:
        #         buf = buf + i
        #     for name, rules in self.comp_decls.items():
        #         buf = buf + ".comp " + name + " {\n"
        #         for r in rules:
        #             buf = buf + r
        #             buf = buf + ".input " + get_rule_name(r) + "\n"
        #         buf = buf + "}\n"
        #     for decl in self.rule_decls:
        #         buf = buf + decl
        #         buf = buf + ".input " + get_rule_name(decl) + "\n"
        # else:
        for decl in self.type_decls:
            buf = buf + decl
        for i in self.inits:
            buf = buf + i
        # write all relation not in comp
        for cname in self.comp_decls.keys():
            buf = buf + ".comp " + cname + " {\n"
            for r in self.relations:
                if (r.is_out or all_out) and r.comp == cname and r.name in select_outs:
                    buf = buf + r.full_text
                    buf = buf + ".input " + r.name + "\n"
            buf = buf + "}\n"
        for r in self.relations:
            if (r.is_out or all_out) and r.comp == "" and r.name in select_outs:
                buf = buf + r.full_text
                buf = buf + '.input ' + r.name + '\n'
        if to_disk:
            with open(self.include_path, 'w+') as f:
                f.write(buf)
        return buf


if __name__ == "__main__":
    parser = OptionParser()
    parser.add_option("-N", "--name", dest="libname")
    parser.add_option("-I", "--output-include", help="output path for include dl file", dest="include_dir")
    parser.add_option("-D", "--dir", action="append", dest="dirs", help="add .output to EVERY relation in a datalog file dir")
    (options, args) = parser.parse_args()
    if options.libname is not None:
        if options.include_dir is None:
            options.include_dir = options.libname + ".dl"
        lib = DatalogLib(options.libname, options.include_dir)
        if options.dirs is not None:
            for d in options.dirs:
                lib.add_dir(d)
            lib.rewrite_rule()
            lib.generate_inlcude(True)
    print("plz check the .init line in your generated file, something optional inside include may also be copied here!")
