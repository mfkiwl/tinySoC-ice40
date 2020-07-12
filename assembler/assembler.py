##############################################################################################################
import re
import sys
import table

##############################################################################################################
# Support Classes
class Symbol:

    def __init__(self):
        self.labelDefs = {}
        self.expr = []

class Code:

    def __init__(self):
        self.data = []
        self.address = 0
        self.label = ""

##############################################################################################################
# File reading functions

def read(name):
    # This function reads in lines from the asm file
    # It processes them and puts them into the form:
    # [[Line_number, Program_Counter] [body] [comment]]
    # Line_number corrisponds to the line on the 
    # source code. the Program_Counter is incremented
    # every time there is a non-empty line (even a comment
    # counts as non empty). Note that two consecutive PC
    # locations do NOT nessisarily corrispond to two
    # consecutive address locations

    # [[Line_number, Program_Counter] [body] 'comment']
    
    file = open(name, 'r')
    lines = []
    lineNumber = 0
    pc = 0
    
    for lineNumber, line in enumerate(file, start = 1):
        line = line.strip()
        line = line.upper()
        if(line):
            block = []
            rest = [] 												   # The input line without the comment
            comment = ''
            commentIndex = line.find(";")
            if(commentIndex != -1):
                comment = line[commentIndex:]
                rest = line[:commentIndex].strip()
            else:
                rest = line

            block.append([lineNumber, pc])
            if(rest): 												   # If we have code after we strip any comment out
                split_rest = re.split(r'([-+,\s]\s*)', rest)
                split_rest = [word for word in split_rest if not re.match(r'^\s*$',word)]
                split_rest = list(filter(None, split_rest))
                block.append(split_rest)
            else:
                block.append([])
            block.append(comment)
            lines.append(block)
            pc += 1
            
    file.close()
    return lines
##############################################################################################################
def lexer(lines):
    tokens = []
    code_lines = [x for x in lines if len(x[1])]                # code_lines only includes lines with code,
    for line in code_lines:                                     # so if a line only has comments, then
        tl = []                                                 # then it's out
        for word in line[1]:
            word = word.strip()
            if word in table.mnm_r_i:
                tl.append(["<mnm_r_i>", word])
            elif word in table.mnm_r_l:
                tl.append(["<mnm_r_l>", word])
            elif word in table.mnm_r_r:
                tl.append(["<mnm_r_r>", word])
            elif word in table.mnm_r:
                tl.append(["<mnm_r>", word])
            elif word in table.mnm_r_rp:
                tl.append(["<mnm_r_rp>", word])
            elif word in table.mnm_rp:
                tl.append(["<mnm_rp>", word])
            elif word in table.mnm_a:
                tl.append(["<mnm_a>", word])
            elif word in table.mnm_n:
                tl.append(["<mnm_n>", word])
            elif word in table.mnm_m:
                tl.append(["<mnm_m>", word])
            elif word == ",":
                tl.append(["<comma>", word])
            elif word == "+":
                tl.append(["<plus>", word])
            elif word == "-":
                tl.append(["<minus>", word])
            elif re.match(r'^R((1*)[02468])|16$',word):
                tl.append(["<reg_even>", word])
            elif re.match(r'^R((1*)[13579])|15$',word):
                tl.append(["<reg_odd>", word])
            elif re.match(r'^.+:$',word):
                tl.append(["<lbl_def>", word])
            elif(re.match(r'^(0X)[0-9A-F]+$', word)):
                tl.append(["<hex_num>", word])
            elif(re.match(r'^[0-9]+$', word)):
                tl.append(["<dec_num>", word])
            elif(re.match(r'^(0B)[0-1]+$', word)):
                tl.append(["<bin_num>", word])    
            elif(re.match(r'^[A-Z_]+[A-Z_]*$', word)):
                tl.append(["<symbol>", word])
            elif word == "$":
                tl.append(["<lc>", word])
            else:
                tl.append(["<idk_man>", word])
                return [0 , 0]

        tokens.append(tl)

    return [code_lines, tokens]
##############################################################################################################
def error(message, line):
    print("Error at line " + str(line[0][0]) + ": " + message)
##############################################################################################################
def parse_expr(tokens, symbols, code, line):
    data = ["<expr>"]
    er = ["<error>"]
    if not tokens:
        return 0
    ##################################################
    while(tokens):
        if(tokens[0][0] in {"<plus>", "<minus>"}):
            data.append(tokens.pop(0))
        elif(len(data) > 1):
            return data
        if(len(data) > 1 and (not tokens)):
            error("Expression missing number/symbol!",line)
            return er
        if(tokens[0][0] not in {"<hex_num>", "<dec_num>", "<bin_num>", "<symbol>", "<lc>"}):
            if(tokens[0][0] not in {"<plus>", "<minus>"}):
                if(len(data) > 1):
                    error("Expression has bad identifier!",line)
                    return er
                else:
                    return 0
            else:
                error("Expression has extra operator!",line)
                return er
        data.append(tokens.pop(0))
    return data
##############################################################################################################
def parse_lbl_def(tokens, symbols, code, line):
    er = ["<error>"]
    if not tokens:
        return 0
    ##################################################
    if(tokens[0][0] == "<lbl_def>"):
        lbl = tokens[0][1]
        if lbl[:-1] in symbols.labelDefs:
            error("Label already in use!",line)
            return er
        elif lbl[:-1] in table.reserved:
            error("Label cannot be keyword!",line)
            return er
        elif re.match(r'^(0X)[0-9A-F]+$',lbl[:-1] or
             re.match(r'^[0-9]+$',lbl[:-1]) or
             re.match(r'^(0B)[0-1]+$')):
            error("Label cannot be number!",line)
            return er
        elif lbl[:-1] in (symbols.defs):
            error("Label conflicts with previous symbol definition",line)
            return er
        else:
            symbols.labelDefs[lbl[:-1]] = '{0:0{1}X}'.format(code.address,4)
            code.label = lbl
        return tokens.pop(0)
    else:
        return 0
##############################################################################################################
def parse_drct(tokens, symbols, code, line):
    args = [tokens, symbols, code, line]
    data = ["<drct>"]
    er = ["<error>"]
    if not tokens:
        return 0
    ##################################################
    # [drct_1]
    if(tokens[0][0] == "<drct_1>"):
        data.append(tokens.pop(0))
        if(not tokens):
            error("Directive missing argument!",line)
            return er
        expr = parse_expr(*args)
        if(not expr):
            error("Directive has bad argument!", line)
            return er
        if(expr == er):
            return er
        data.append(expr)
        arg = data[2][1:]
        status = directives[data[1][1]][0](arg,symbols,code,line)
        if not status:
            return er
        return data
##############################################################################################################
def parse_code(tokens, symbols, code, line):
    args = [tokens, symbols, code, line]
    data = ["<code>"]
    er = ["<error>"]
    if not tokens:
        return 0
    ##################################################
    # [mnm_r_i] || [mnm_r_l]
    if(tokens[0][0] == "<mnm_r_i>" || tokens[0][0] == "<mnm_r_l>"):
        inst = tokens[0][1]
        data.append(tokens.pop(0))
        if(not tokens):
            error("Instruction missing register!",line)
            return er
        if(tokens[0][0] != "<reg_even>" || tokens[0][0] != "<reg_odd>")
            error("Instruction has a bad register!",line)
            return er
        reg1 = tokens[0][1]
        data.append(tokens.pop(0))
        if(not tokens):
            error("Instruction missing comma and argument!",line)
            return er
        if(tokens[0][0] != "<comma>"):
            if(tokens[0][0] not in {"<hex_num>","<dec_num>","<bin_num>","<symbol>"}):
                error("Instruction has bad argument!",line)
                return er
            error("Instruction missing comma!",line)
            return er
        data.append(tokens.pop(0))
        if(not tokens):
            error("Instruction missing argument!",line)
            return er
        expr = parse_expr(*args)
        if(not expr):
            error("Instruction has bad argument!",line)
            return er
        elif(expr == er):
            return er
        data.append(expr)
    ##################################################
    # [mnm_r_r]
    if(tokens[0][0] == "<mnm_r_r>"):
        inst = tokens[0][1]
        data.append(tokens.pop(0))
        if(not tokens):
            error("Instruction missing register!",line)
            return er
        if(tokens[0][0] != "<reg_even>" || tokens[0][0] != "<reg_odd>")
            error("Instruction has a bad register!",line)
            return er
        reg1 = tokens[0][1]
        data.append(tokens.pop(0))
        if(not tokens):
            error("Instruction missing comma and register!",line)
            return er
        if(tokens[0][0] != "<comma>"):
            if(tokens[0][0] != "<reg_even>" || tokens[0][0] != "<reg_odd>")
                error("Instruction has a bad register!",line)
                return er
            error("Instruction missing comma!",line)
            return er
        data.append(tokens.pop(0))
        if(not tokens):
            error("Instruction missing register!",line)
            return er
        if(tokens[0][0] != "<reg_even>" || tokens[0][0] != "<reg_odd>")
            error("Instruction has a bad register!",line)
            return er
        reg2 = tokens[0][1]
        data.append(tokens.pop(0))
    ##################################################
    # [mnm_r]
    if(tokens[0][0] == "<mnm_r>"):
        inst = tokens[0][1]
        data.append(tokens.pop(0))
        if(not tokens):
            error("Instruction missing register!",line)
            return er
        if(tokens[0][0] != "<reg_even>" || tokens[0][0] != "<reg_odd>")
            error("Instruction has a bad register!",line)
            return er
        reg1 = tokens[0][1]
        data.append(tokens.pop(0))
    ##################################################
    # [mnm_r_rp]
    if(tokens[0][0] == "<mnm_r_rp>"):
        inst = tokens[0][1]
        data.append(tokens.pop(0))
        if(not tokens):
            error("Instruction missing register!",line)
            return er
        if(tokens[0][0] != "<reg_even>" || tokens[0][0] != "<reg_odd>")
            error("Instruction has a bad register!",line)
            return er
        reg1 = tokens[0][1]
        data.append(tokens.pop(0))
        if(not tokens):
            error("Instruction missing comma and register!",line)
            return er
        if(tokens[0][0] != "<comma>"):
            if(tokens[0][0] != "<reg_even>")
                error("Instruction has a bad rp register!",line)
                return er
            error("Instruction missing comma!",line)
            return er
        data.append(tokens.pop(0))
        if(not tokens):
            error("Instruction missing rp register!",line)
            return er
        if(tokens[0][0] != "<reg_even>")
            error("Instruction has a bad rp register!",line)
            return er
        reg2 = tokens[0][1]
        data.append(tokens.pop(0))
    ##################################################
    # [mnm_rp]
    if(tokens[0][0] == "<mnm_rp>"):
        inst = tokens[0][1]
        data.append(tokens.pop(0))
        if(not tokens):
            error("Instruction missing rp register!",line)
            return er
        if(tokens[0][0] != "<reg_even>")
            error("Instruction has a bad rp register!",line)
            return er
        reg1 = tokens[0][1]
        data.append(tokens.pop(0))
##############################################################################################################
# Grammar:
#
# <line> ::= <lbl_def> [<drct>] [<code>]
#          | <drct> [<code>]
#          | <code>
#
# <code> ::= <mnm_r_i> <reg> "," <expr>
#          | <mnm_r_l> <reg> "," <expr>
#          | <mnm_r_r> <reg> "," <reg>
#          | <mnm_r> <reg>
#          | <mnm_r_rp> <reg> "," <reg_even>
#          | <mnm_rp> <reg_even>
#          | <mnm_a> <expr>
#          | <mnm_n>
#          | <mnm_m> <expr>
#
# <reg>  ::= <reg_even>
#          | <reg_odd>
#
# <expr> ::= [ (<plus> | <minus>) ] <numb> { (<plus> | <minus>) <numb> }
#
# <drct> ::= <drct_1> <expr>
#          | <drct_p> <expr> { ","  <expr> }
#
# <numb> ::= <hex_num> | <dec_num> | <bin_num> | <symbol> | <lc>
##############################################################################################################
def parse_line():
    data = ["<line>"]
    er = ["<error>"]
    if(len(tokens) == 0):
        return 0
    ################################
    # [lbl_def]
    lbl_def = parse_lbl_def(tokens, symbols, code, line)
    if(lbl_def):
        if(lbl_def == er):
            return er
        data.append(lbl_def)
    ################################
    # [drct]
    drct = parse_drct(tokens, symbols, code, line)
    if(drct):
        if(drct == er):
            return er
        data.append(drct)
    ################################
    # [code]
    code = parse_code(tokens, symbols, code, line)
    if(code):
        if(code == er):
            return er
        data.append(code)
    ###############################
    # check to see that we have at
    # least one of lbl_def, drct,
    # or code
    if(let(data) < 2):
        tokens.pop(0)
        error("Bad Initial Identifier!",line)
        return er
    ###############################
    # check to see if we have any
    # tokens left
    if(len(tokens)):   
        error("Bad Final Identifier(s)!",line)
        return er
    ###############################
    # everything's good
    return data
##############################################################################################################
code_lines, tokens = lexer(read("programs/demo.asm"));

if(code_lines == 0)
    sys.exit(1)

tree = []
