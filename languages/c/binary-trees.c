#include <stdio.h>
#include <stdlib.h>

typedef struct Node {
    struct Node *left, *right;
} Node;

static Node *make(int depth) {
    Node *n = malloc(sizeof(Node));
    if (depth == 0) {
        n->left = n->right = NULL;
    } else {
        n->left = make(depth - 1);
        n->right = make(depth - 1);
    }
    return n;
}

static long check(Node *n) {
    if (n->left == NULL) return 1;
    return 1 + check(n->left) + check(n->right);
}

static void destroy(Node *n) {
    if (n->left != NULL) { destroy(n->left); destroy(n->right); }
    free(n);
}

static long run(int n) {
    int min_depth = 4;
    int max_depth = (min_depth + 2 > n) ? min_depth + 2 : n;
    int stretch_depth = max_depth + 1;

    Node *stretch = make(stretch_depth);
    long total = check(stretch);
    destroy(stretch);

    Node *long_lived = make(max_depth);

    int depth = min_depth;
    while (depth <= max_depth) {
        int iterations = 1 << (max_depth - depth + min_depth);
        long s = 0;
        for (int i = 0; i < iterations; i++) {
            Node *t = make(depth);
            s += check(t);
            destroy(t);
        }
        total += s;
        depth += 2;
    }

    total += check(long_lived);
    destroy(long_lived);
    return total;
}

int main(int argc, char **argv) {
    int n = argc > 1 ? atoi(argv[1]) : 10;
    printf("%ld\n", run(n));
    printf("binary-trees(%d)\n", n);
    return 0;
}
