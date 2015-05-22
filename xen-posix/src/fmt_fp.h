#define ALT_FORM   (1U<<('#'-' '))
#define ZERO_PAD   (1U<<('0'-' '))
#define LEFT_ADJ   (1U<<('-'-' '))
#define PAD_POS    (1U<<(' '-' '))
#define MARK_POS   (1U<<('+'-' '))
#define GROUPED    (1U<<('\''-' '))

typedef struct _buffer buffer_t;

void out(buffer_t *f, const char *s, size_t l);
int fmt_fp(buffer_t *f, long double y, int w, int p, int fl, int t);
