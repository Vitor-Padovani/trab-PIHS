#include <stdio.h>
#include <string.h>
#include <stdbool.h>

#define MAX_LINE 256

long vars[26];
char func_param[26];
char func_body[26][MAX_LINE];
bool func_defined[26];

long eval_expr(const char *line, int start, int end);

long read_term(const char *line, int *pos, int end) {
    char c = line[*pos];

    if (c >= '0' && c <= '9') {
        long num = 0;
        while (*pos < end && line[*pos] >= '0' && line[*pos] <= '9') {
            num = num * 10 + (line[*pos] - '0');
            (*pos)++;
        }
        return num;
    }

    if (c >= 'a' && c <= 'z') {
        char name = c;

        if (*pos + 1 < end && line[*pos + 1] == '(') {
            *pos += 2;

            int arg_start = *pos;
            int depth = 1;
            while (depth > 0) {
                if (line[*pos] == '(') depth++;
                else if (line[*pos] == ')') depth--;
                if (depth > 0) (*pos)++;
            }
            int arg_end = *pos;
            (*pos)++;

            long arg_value = eval_expr(line, arg_start, arg_end);

            char param = func_param[name - 'a'];
            const char *body = func_body[name - 'a'];

            long saved = vars[param - 'a'];
            vars[param - 'a'] = arg_value;
            long result = eval_expr(body, 0, (int)strlen(body));
            vars[param - 'a'] = saved;
            return result;
        }

        (*pos)++;
        return vars[name - 'a'];
    }

    (*pos)++;
    return 0;
}

long eval_expr(const char *line, int start, int end) {
    int pos = start;
    long result = 0;
    int sign = 1;

    while (pos < end) {
        long term = read_term(line, &pos, end);
        result += sign * term;

        if (pos < end) {
            if (line[pos] == '+') { sign = 1; pos++; }
            else if (line[pos] == '-') { sign = -1; pos++; }
        }
    }

    return result;
}

void handle_var_assignment(const char *line, int len) {
    char var_name = line[0];
    long value = eval_expr(line, 2, len);
    vars[var_name - 'a'] = value;
}

void handle_func_definition(const char *line, int len) {
    char func_name = line[0];
    char param_name = line[2];

    int body_start = 5;
    int body_len = len - body_start;

    func_param[func_name - 'a'] = param_name;
    memcpy(func_body[func_name - 'a'], line + body_start, body_len);
    func_body[func_name - 'a'][body_len] = '\0';
    func_defined[func_name - 'a'] = true;
}

bool contains_equal(const char *line, int len) {
    for (int i = 0; i < len; i++) {
        if (line[i] == '=') return true;
    }
    return false;
}

int main(void) {
    char line[MAX_LINE];

    while (scanf("%255s", line) == 1) {
        int len = (int)strlen(line);

        if (len > 1 && line[1] == '(') {
            if (contains_equal(line, len)) {
                handle_func_definition(line, len);
            } else {
                long result = eval_expr(line, 0, len);
                printf("%ld\n", result);
            }
        } else if (len > 1 && line[1] == '=') {
            handle_var_assignment(line, len);
        } else {
            long result = eval_expr(line, 0, len);
            printf("%ld\n", result);
        }
    }

    return 0;
}