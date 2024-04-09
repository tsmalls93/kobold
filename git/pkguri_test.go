package git

import (
	"testing"

	"code.gitea.io/gitea/modules/url"
)

func TestPkgUri(t *testing.T) {
	t.Parallel()

	var cases = []struct {
		name string
		uri  string
	}{
		{
			name: "http",
			uri:  "https://github.com/kubernetes/kubernetes.git",
		},
		{
			name: "ssh",
			uri:  "ssh://git@github.com:kubernetes/kubernetes.git",
		},
	}

	for _, c := range cases {
		c := c
		t.Run(c.name, func(t *testing.T) {
			t.Parallel()

			u, err := url.Parse(c.uri)
			if err != nil {
				t.Fatal(err)
			}

			t.Logf("u: %v", u)
		})
	}

}
